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
import {TickMath} from "../lib/v4-core/src/libraries/TickMath.sol";
import {PoolModifyLiquidityTest} from "../lib/v4-core/src/test/PoolModifyLiquidityTest.sol";
import {PoolSwapTest} from "../lib/v4-core/src/test/PoolSwapTest.sol";
import {HookMiner} from "../lib/v4-periphery/src/utils/HookMiner.sol";

import "../src/StreetRateHookV4Simple.sol";
import "../src/HybridRateOracle.sol";
import "../src/tokens/FiatTokens.sol";

contract DeployToSepolia is Script {
    using PoolIdLibrary for PoolKey;
    
    // Deployment addresses (will be saved)
    struct DeploymentAddresses {
        address ngn;
        address ars;
        address ghs;
        address usdc;
        address oracle;
        address poolManager;
        address hook;
        address modifyLiquidityRouter;
        address swapRouter;
        bytes32 ngnUsdcPoolId;
        bytes32 arsUsdcPoolId;
        bytes32 ghsUsdcPoolId;
    }
    
    DeploymentAddresses public deployments;
    
    // Pool configuration
    uint24 constant FEE = 3000; // 0.3%
    int24 constant TICK_SPACING = 60;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("\n=== Deploying to Sepolia Testnet ===");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance / 1e18, "ETH");
        
        require(deployer.balance > 0.01 ether, "Insufficient ETH for deployment");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy in stages to avoid stack too deep
        deployTokens();
        deployCore(deployer);
        deployHook(deployer);
        createPools();
        mintTokens(deployer);
        
        vm.stopBroadcast();
        
        // Save deployment addresses
        saveDeploymentAddresses();
        
        console.log("\n=== Deployment Complete ===");
        printDeploymentSummary();
    }
    
    function deployTokens() internal {
        console.log("\n1. Deploying mock tokens...");
        deployments.ngn = address(new NGNToken());
        deployments.ars = address(new ARSToken());
        deployments.ghs = address(new GHSToken());
        deployments.usdc = address(new USDCMock());
        
        console.log("  NGN:", deployments.ngn);
        console.log("  ARS:", deployments.ars);
        console.log("  GHS:", deployments.ghs);
        console.log("  USDC:", deployments.usdc);
    }
    
    function deployCore(address deployer) internal {
        console.log("\n2. Deploying core contracts...");
        
        // Deploy oracle
        HybridRateOracle oracle = new HybridRateOracle();
        oracle.initializeDefaultRates(
            deployments.ngn,
            deployments.ars,
            deployments.ghs,
            deployments.usdc
        );
        deployments.oracle = address(oracle);
        console.log("  Oracle:", deployments.oracle);
        
        // Deploy PoolManager
        deployments.poolManager = address(new PoolManager(deployer));
        console.log("  PoolManager:", deployments.poolManager);
        
        // Deploy routers
        deployments.modifyLiquidityRouter = address(new PoolModifyLiquidityTest(IPoolManager(deployments.poolManager)));
        deployments.swapRouter = address(new PoolSwapTest(IPoolManager(deployments.poolManager)));
        console.log("  Routers deployed");
    }
    
    function deployHook(address deployer) internal {
        console.log("\n3. Deploying hook with CREATE2...");
        uint256 deviationThreshold = 7000;
        
        // Only require beforeSwap flag for now
        uint160 permissions = uint160(Hooks.BEFORE_SWAP_FLAG);
        
        // Mine for a salt that produces an address with the correct flags
        bytes memory creationCode = type(StreetRateHookV4Simple).creationCode;
        bytes memory constructorArgs = abi.encode(deployments.poolManager, deployments.oracle, deviationThreshold);
        
        (address hookAddress, bytes32 salt) = HookMiner.find(
            deployer,
            permissions,
            creationCode,
            constructorArgs
        );
        
        console.log("  Target hook address:", hookAddress);
        console.log("  Salt:", uint256(salt));
        
        // Verify the address has the correct flags before deploying
        uint256 flags = uint256(uint160(hookAddress)) & 0xFFFF;
        console.log("  Address flags:", flags);
        require((flags & 0x80) != 0, "beforeSwap flag not set in address");
        
        // Deploy the hook
        StreetRateHookV4Simple hook = new StreetRateHookV4Simple{salt: salt}(
            IPoolManager(deployments.poolManager),
            IStreetRateOracle(deployments.oracle),
            deviationThreshold
        );
        
        require(address(hook) == hookAddress, "Hook address mismatch");
        deployments.hook = address(hook);
        console.log("  Hook deployed at:", deployments.hook);
    }
    
    function createPools() internal {
        console.log("\n4. Creating currency pools...");
        
        deployments.ngnUsdcPoolId = createPool(
            deployments.ngn,
            deployments.usdc,
            deployments.hook,
            IPoolManager(deployments.poolManager),
            "NGN/USDC"
        );
        
        deployments.arsUsdcPoolId = createPool(
            deployments.ars,
            deployments.usdc,
            deployments.hook,
            IPoolManager(deployments.poolManager),
            "ARS/USDC"
        );
        
        deployments.ghsUsdcPoolId = createPool(
            deployments.ghs,
            deployments.usdc,
            deployments.hook,
            IPoolManager(deployments.poolManager),
            "GHS/USDC"
        );
    }
    
    function mintTokens(address recipient) internal {
        console.log("\n5. Minting test tokens...");
        
        NGNToken(deployments.ngn).mint(recipient, 10_000_000e18);
        ARSToken(deployments.ars).mint(recipient, 10_000_000e18);
        GHSToken(deployments.ghs).mint(recipient, 100_000e18);
        USDCMock(deployments.usdc).mint(recipient, 100_000e6);
        
        console.log("  Tokens minted to:", recipient);
    }
    
    function createPool(
        address token0,
        address token1,
        address hook,
        IPoolManager poolManager,
        string memory pairName
    ) internal returns (bytes32) {
        // Sort tokens
        (Currency currency0, Currency currency1) = token0 < token1 ? 
            (Currency.wrap(token0), Currency.wrap(token1)) :
            (Currency.wrap(token1), Currency.wrap(token0));
        
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(hook)
        });
        
        // Calculate initial price based on street rate
        uint160 sqrtPriceX96 = getSqrtPriceX96(token0, token1);
        
        poolManager.initialize(poolKey, sqrtPriceX96);
        
        bytes32 poolId = PoolId.unwrap(poolKey.toId());
        console.log("  ", pairName, "pool created. ID:", uint256(poolId));
        
        return poolId;
    }
    
    function getSqrtPriceX96(address token0, address token1) internal pure returns (uint160) {
        // Return appropriate sqrt price based on pair
        // These are approximations for the street rates
        if (token0 == token1) revert("Same token");
        
        // Default price (can be adjusted based on actual rates)
        return 2045951728901457409024; // Approximately sqrt(0.000667) * 2^96
    }

    
    function saveDeploymentAddresses() internal {
        string memory json = "deployments";
        
        vm.serializeAddress(json, "ngn", deployments.ngn);
        vm.serializeAddress(json, "ars", deployments.ars);
        vm.serializeAddress(json, "ghs", deployments.ghs);
        vm.serializeAddress(json, "usdc", deployments.usdc);
        vm.serializeAddress(json, "oracle", deployments.oracle);
        vm.serializeAddress(json, "poolManager", deployments.poolManager);
        vm.serializeAddress(json, "hook", deployments.hook);
        vm.serializeAddress(json, "modifyLiquidityRouter", deployments.modifyLiquidityRouter);
        vm.serializeAddress(json, "swapRouter", deployments.swapRouter);
        vm.serializeBytes32(json, "ngnUsdcPoolId", deployments.ngnUsdcPoolId);
        vm.serializeBytes32(json, "arsUsdcPoolId", deployments.arsUsdcPoolId);
        string memory output = vm.serializeBytes32(json, "ghsUsdcPoolId", deployments.ghsUsdcPoolId);
        
        vm.writeJson(output, "./deployments/sepolia.json");
        console.log("\nDeployment addresses saved to deployments/sepolia.json");
    }
    
    function printDeploymentSummary() internal view {
        console.log("\n========================================");
        console.log("       SEPOLIA DEPLOYMENT SUMMARY");
        console.log("========================================");
        console.log("\nTOKENS:");
        console.log("  NGN:  ", deployments.ngn);
        console.log("  ARS:  ", deployments.ars);
        console.log("  GHS:  ", deployments.ghs);
        console.log("  USDC: ", deployments.usdc);
        console.log("\nCONTRACTS:");
        console.log("  Oracle:      ", deployments.oracle);
        console.log("  PoolManager: ", deployments.poolManager);
        console.log("  Hook:        ", deployments.hook);
        console.log("\nROUTERS:");
        console.log("  Liquidity:   ", deployments.modifyLiquidityRouter);
        console.log("  Swap:        ", deployments.swapRouter);
        console.log("\nPOOLS:");
        console.log("  NGN/USDC ID: ", uint256(deployments.ngnUsdcPoolId));
        console.log("  ARS/USDC ID: ", uint256(deployments.arsUsdcPoolId));
        console.log("  GHS/USDC ID: ", uint256(deployments.ghsUsdcPoolId));
        console.log("========================================");
    }
}
