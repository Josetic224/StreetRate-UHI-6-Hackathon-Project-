// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {IPoolManager} from "../lib/v4-core/src/interfaces/IPoolManager.sol";
import {Currency} from "../lib/v4-core/src/types/Currency.sol";
import {PoolKey} from "../lib/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "../lib/v4-core/src/types/PoolId.sol";
import {IHooks} from "../lib/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "../lib/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "../lib/v4-periphery/src/utils/HookMiner.sol";

import "../src/StreetRateHookV4Simple.sol";
import "../src/HybridRateOracle.sol";
import "../src/tokens/FiatTokens.sol";

contract FixDeployment is Script {
    using PoolIdLibrary for PoolKey;
    
    // Already deployed and working contracts
    address constant NGN = 0x9ac0ec34c027A77a9aeB46Ee9167ceed4CC5734D;
    address constant GHS = 0xd2B1132937315B4161670B652F8D158D39bAf2D5;
    address constant USDC = 0x1fFdf1a9DB25c1b1Ed8f3026d98e4349d01234C3;
    address constant ORACLE = 0xd35fCdCeC137756A3F6da6d75beF82506E90A1cE;
    address constant POOL_MANAGER = 0x2FfB75fbf5707848CDdd942921D76933c7BBd90C;
    
    // The address that has both ARS and Hook (collision)
    address constant COLLISION_ADDRESS = 0x6E3358Bc9E80b72a2F1E971Ae5e5E75D29a1a4c2;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("\n=== Fixing Sepolia Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance / 1e18, "ETH");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy a new ARS token
        console.log("\n1. Deploying new ARS token...");
        ARSToken newARS = new ARSToken();
        address arsAddress = address(newARS);
        console.log("  New ARS token deployed at:", arsAddress);
        
        // Step 2: Deploy a new Hook with CREATE2 to get proper flags
        console.log("\n2. Deploying new Hook with CREATE2...");
        address hookAddress = deployHookWithCreate2(deployer);
        console.log("  New Hook deployed at:", hookAddress);
        
        // Step 3: Update oracle with new ARS token
        console.log("\n3. Updating oracle with new ARS token...");
        HybridRateOracle oracle = HybridRateOracle(ORACLE);
        
        // Configure ARS/USDC rates
        oracle.updateRates(
            arsAddress,
            USDC,
            2860000000000000,  // Official: 0.00286 USDC per ARS (350 ARS/USD)
            1000000000000000   // Street: 0.001 USDC per ARS (1000 ARS/USD)
        );
        console.log("  Oracle updated with new ARS token");
        
        // Step 4: Create pools with the new hook
        console.log("\n4. Creating pools...");
        
        // NGN/USDC pool
        bytes32 ngnPoolId = createPool(NGN, USDC, hookAddress, "NGN/USDC");
        
        // New ARS/USDC pool
        bytes32 arsPoolId = createPool(arsAddress, USDC, hookAddress, "ARS/USDC");
        
        // GHS/USDC pool
        bytes32 ghsPoolId = createPool(GHS, USDC, hookAddress, "GHS/USDC");
        
        // Step 5: Mint test tokens
        console.log("\n5. Minting test tokens...");
        newARS.mint(deployer, 10_000_000e18);
        console.log("  Minted 10M ARS to deployer");
        
        vm.stopBroadcast();
        
        // Print final summary
        printSummary(arsAddress, hookAddress, ngnPoolId, arsPoolId, ghsPoolId);
    }
    
    function deployHookWithCreate2(address deployer) internal returns (address) {
        uint256 deviationThreshold = 7000;
        
        // Only require beforeSwap flag
        uint160 permissions = uint160(Hooks.BEFORE_SWAP_FLAG);
        
        // Mine for a salt that produces an address with correct flags
        (address targetHookAddress, bytes32 salt) = HookMiner.find(
            deployer,
            permissions,
            type(StreetRateHookV4Simple).creationCode,
            abi.encode(POOL_MANAGER, ORACLE, deviationThreshold)
        );
        
        console.log("  Target hook address:", targetHookAddress);
        console.log("  Salt found:", uint256(salt));
        
        // Verify the address has correct flags
        uint256 flags = uint256(uint160(targetHookAddress)) & 0xFFFF;
        require((flags & 0x80) != 0, "beforeSwap flag not set");
        
        // Deploy the hook
        StreetRateHookV4Simple hook = new StreetRateHookV4Simple{salt: salt}(
            IPoolManager(POOL_MANAGER),
            IStreetRateOracle(ORACLE),
            deviationThreshold
        );
        
        require(address(hook) == targetHookAddress, "Hook address mismatch");
        
        return address(hook);
    }
    
    function createPool(
        address token0,
        address token1,
        address hook,
        string memory pairName
    ) internal returns (bytes32) {
        // Sort tokens
        (Currency currency0, Currency currency1) = token0 < token1 ? 
            (Currency.wrap(token0), Currency.wrap(token1)) :
            (Currency.wrap(token1), Currency.wrap(token0));
        
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
        
        // Initialize pool with appropriate price
        uint160 sqrtPriceX96 = getSqrtPriceForPair(token0, token1);
        IPoolManager(POOL_MANAGER).initialize(poolKey, sqrtPriceX96);
        
        bytes32 poolId = PoolId.unwrap(poolKey.toId());
        console.log("  ", pairName, "pool created");
        
        return poolId;
    }
    
    function getSqrtPriceForPair(address token0, address token1) internal pure returns (uint160) {
        // Return appropriate sqrt price based on pair
        // These are approximations for the street rates
        
        // NGN/USDC: 1 NGN = 0.000667 USDC
        if ((token0 == NGN && token1 == USDC) || (token0 == USDC && token1 == NGN)) {
            return 2045951728901457409024; // sqrt(0.000667) * 2^96
        }
        
        // GHS/USDC: 1 GHS = 0.0667 USDC
        if ((token0 == GHS && token1 == USDC) || (token0 == USDC && token1 == GHS)) {
            return 20459517289014574090240; // sqrt(0.0667) * 2^96
        }
        
        // Default for ARS/USDC: 1 ARS = 0.001 USDC
        return 2505414483750479311864; // sqrt(0.001) * 2^96
    }
    
    function printSummary(
        address newARS,
        address newHook,
        bytes32 ngnPoolId,
        bytes32 arsPoolId,
        bytes32 ghsPoolId
    ) internal view {
        console.log("\n========================================");
        console.log("     FIXED DEPLOYMENT SUMMARY");
        console.log("========================================");
        console.log("\nTOKENS:");
        console.log("  NGN:  ", NGN);
        console.log("  ARS:  ", newARS, "(NEW)");
        console.log("  GHS:  ", GHS);
        console.log("  USDC: ", USDC);
        console.log("\nCONTRACTS:");
        console.log("  Oracle:      ", ORACLE);
        console.log("  PoolManager: ", POOL_MANAGER);
        console.log("  Hook:        ", newHook, "(NEW)");
        console.log("\nPOOLS CREATED:");
        console.log("  NGN/USDC: ", uint256(ngnPoolId));
        console.log("  ARS/USDC: ", uint256(arsPoolId));
        console.log("  GHS/USDC: ", uint256(ghsPoolId));
        console.log("\nOLD COLLISION ADDRESS:");
        console.log("  ", COLLISION_ADDRESS, "(was both ARS and Hook)");
        console.log("========================================");
        console.log("\nDeployment fixed! All contracts now have unique addresses.");
        console.log("Pools are created and ready for liquidity and swaps.");
    }
}
