// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {IPoolManager} from "../lib/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "../lib/v4-core/src/PoolManager.sol";
import {Currency} from "../lib/v4-core/src/types/Currency.sol";
import {PoolKey} from "../lib/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "../lib/v4-core/src/types/PoolId.sol";
import {IHooks} from "../lib/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "../lib/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "../lib/v4-periphery/src/utils/HookMiner.sol";

import "../src/StreetRateHookV4Simple.sol";
import "../src/HybridRateOracle.sol";

contract ContinueDeployment is Script {
    using PoolIdLibrary for PoolKey;
    
    // Already deployed addresses from previous attempt
    address constant NGN = 0x9ac0ec34c027A77a9aeB46Ee9167ceed4CC5734D;
    address constant ARS = 0x6E3358Bc9E80b72a2F1E971Ae5e5E75D29a1a4c2;
    address constant GHS = 0xd2B1132937315B4161670B652F8D158D39bAf2D5;
    address constant USDC = 0x1fFdf1a9DB25c1b1Ed8f3026d98e4349d01234C3;
    address constant ORACLE = 0xd35fCdCeC137756A3F6da6d75beF82506E90A1cE;
    address constant POOL_MANAGER = 0x2FfB75fbf5707848CDdd942921D76933c7BBd90C;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("\n=== Continuing Sepolia Deployment ===");
        console.log("Deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy hook without CREATE2 first (simpler approach)
        console.log("\n1. Deploying hook (simplified)...");
        StreetRateHookV4Simple hook = new StreetRateHookV4Simple(
            IPoolManager(POOL_MANAGER),
            IStreetRateOracle(ORACLE),
            7000 // 70% deviation threshold
        );
        
        address hookAddress = address(hook);
        console.log("  Hook deployed at:", hookAddress);
        
        // Check if address has any hook flags (not strict requirement)
        uint256 flags = uint256(uint160(hookAddress)) & 0xFFFF;
        console.log("  Address flags:", flags);
        
        // Create pools
        console.log("\n2. Creating pools...");
        
        // NGN/USDC pool
        createPool(NGN, USDC, hookAddress, "NGN/USDC");
        
        // ARS/USDC pool
        createPool(ARS, USDC, hookAddress, "ARS/USDC");
        
        // GHS/USDC pool
        createPool(GHS, USDC, hookAddress, "GHS/USDC");
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Complete ===");
        printSummary(hookAddress);
    }
    
    function createPool(
        address token0,
        address token1,
        address hook,
        string memory pairName
    ) internal {
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
        
        // Initialize pool
        uint160 sqrtPriceX96 = 2045951728901457409024;
        IPoolManager(POOL_MANAGER).initialize(poolKey, sqrtPriceX96);
        
        bytes32 poolId = PoolId.unwrap(poolKey.toId());
        console.log("  ", pairName, "pool created");
    }
    
    function printSummary(address hook) internal pure {
        console.log("\n========================================");
        console.log("       DEPLOYMENT SUMMARY");
        console.log("========================================");
        console.log("\nTOKENS:");
        console.log("  NGN:  ", NGN);
        console.log("  ARS:  ", ARS);
        console.log("  GHS:  ", GHS);
        console.log("  USDC: ", USDC);
        console.log("\nCONTRACTS:");
        console.log("  Oracle:      ", ORACLE);
        console.log("  PoolManager: ", POOL_MANAGER);
        console.log("  Hook:        ", hook);
        console.log("========================================");
        console.log("\nNext steps:");
        console.log("1. Verify contracts on Etherscan");
        console.log("2. Add liquidity to pools");
        console.log("3. Test swaps");
    }
}
