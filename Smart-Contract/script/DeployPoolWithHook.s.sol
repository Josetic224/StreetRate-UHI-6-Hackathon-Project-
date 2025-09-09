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
import {SqrtPriceMath} from "../lib/v4-core/src/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "../lib/v4-core/test/utils/LiquidityAmounts.sol";
import {PoolModifyLiquidityTest} from "../lib/v4-core/src/test/PoolModifyLiquidityTest.sol";
import {PoolSwapTest} from "../lib/v4-core/src/test/PoolSwapTest.sol";
import {HookMiner} from "../lib/v4-periphery/src/utils/HookMiner.sol";

import "../src/StreetRateHookV4Simple.sol";
import "../src/HybridRateOracle.sol";
import "../src/tokens/FiatTokens.sol";

contract DeployPoolWithHook is Script {
    using PoolIdLibrary for PoolKey;
    
    // Core contracts
    IPoolManager public poolManager;
    PoolModifyLiquidityTest public modifyLiquidityRouter;
    PoolSwapTest public swapRouter;
    
    // Our contracts
    StreetRateHookV4Simple public hook;
    HybridRateOracle public oracle;
    
    // Tokens
    NGNToken public ngn;
    ARSToken public ars;
    GHSToken public ghs;
    USDCMock public usdc;
    
    // Pool configuration
    uint24 constant FEE = 3000; // 0.3%
    int24 constant TICK_SPACING = 60;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        if (deployerPrivateKey == 0) {
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        }
        
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("\n=== Deploying Uniswap v4 Pool with Street Rate Hook ===\n");
        
        // Step 1: Deploy tokens
        console.log("Step 1: Deploying tokens...");
        ngn = new NGNToken();
        ars = new ARSToken();
        ghs = new GHSToken();
        usdc = new USDCMock();
        
        console.log("  NGN:", address(ngn));
        console.log("  ARS:", address(ars));
        console.log("  GHS:", address(ghs));
        console.log("  USDC:", address(usdc));
        
        // Step 2: Deploy oracle and configure rates
        console.log("\nStep 2: Deploying oracle...");
        oracle = new HybridRateOracle();
        oracle.initializeDefaultRates(
            address(ngn),
            address(ars),
            address(ghs),
            address(usdc)
        );
        console.log("  Oracle:", address(oracle));
        
        // Step 3: Deploy PoolManager
        console.log("\nStep 3: Deploying PoolManager...");
        poolManager = new PoolManager(deployer);  // deployer is the owner
        console.log("  PoolManager:", address(poolManager));
        
        // Step 4: Deploy test routers
        console.log("\nStep 4: Deploying routers...");
        modifyLiquidityRouter = new PoolModifyLiquidityTest(poolManager);
        swapRouter = new PoolSwapTest(poolManager);
        console.log("  ModifyLiquidityRouter:", address(modifyLiquidityRouter));
        console.log("  SwapRouter:", address(swapRouter));
        
        // Step 5: Mine for hook address with CREATE2
        console.log("\nStep 5: Mining for hook address...");
        uint256 deviationThreshold = 7000; // 70% for demo
        
        // Find a salt that produces a valid hook address
        uint160 permissions = uint160(
            Hooks.BEFORE_SWAP_FLAG | 
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );
        
        (address hookAddress, bytes32 salt) = HookMiner.find(
            deployer,
            permissions,
            type(StreetRateHookV4Simple).creationCode,
            abi.encode(address(poolManager), address(oracle), deviationThreshold)
        );
        
        console.log("  Target hook address:", hookAddress);
        console.log("  Salt:", uint256(salt));
        
        // Step 6: Deploy hook with CREATE2
        console.log("\nStep 6: Deploying hook with CREATE2...");
        hook = new StreetRateHookV4Simple{salt: salt}(
            poolManager,
            oracle,
            deviationThreshold
        );
        console.log("  Hook deployed at:", address(hook));
        require(address(hook) == hookAddress, "Hook address mismatch");
        
        // Step 7: Create and initialize NGN/USDC pool
        console.log("\nStep 7: Creating NGN/USDC pool...");
        
        // Sort tokens for pool key
        (Currency currency0, Currency currency1) = address(ngn) < address(usdc) ? 
            (Currency.wrap(address(ngn)), Currency.wrap(address(usdc))) :
            (Currency.wrap(address(usdc)), Currency.wrap(address(ngn)));
        
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(hook))
        });
        
        // Calculate initial price (1 NGN = 0.000667 USDC at street rate)
        // sqrtPriceX96 = sqrt(price) * 2^96
        // price = 0.000667 USDC/NGN
        uint160 sqrtPriceX96 = 2045951728901457409024; // Approximately sqrt(0.000667) * 2^96
        
        poolManager.initialize(poolKey, sqrtPriceX96);
        bytes32 poolIdBytes = PoolId.unwrap(poolKey.toId());
        console.log("  Pool initialized");
        
        // Step 8: Add liquidity to the pool
        console.log("\nStep 8: Adding liquidity...");
        
        // Mint tokens to the router for liquidity
        uint256 ngnAmount = 1000000e18; // 1M NGN
        uint256 usdcAmount = 1000e6; // 1000 USDC
        
        ngn.mint(address(modifyLiquidityRouter), ngnAmount);
        usdc.mint(address(modifyLiquidityRouter), usdcAmount);
        
        // Approve router to spend tokens
        vm.stopBroadcast();
        vm.startBroadcast(deployerPrivateKey);
        
        // Add liquidity
        int24 tickLower = -887220; // Full range
        int24 tickUpper = 887220;
        uint256 liquidity = 1000000e18;
        
        modifyLiquidityRouter.modifyLiquidity(
            poolKey,
            IPoolManager.ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int256(liquidity),
                salt: bytes32(0)
            }),
            new bytes(0)
        );
        
        console.log("  Liquidity added: ", liquidity);
        
        // Step 9: Prepare for swaps
        console.log("\nStep 9: Preparing for swaps...");
        
        // Mint tokens to swap router for testing
        ngn.mint(address(swapRouter), 10000e18);
        usdc.mint(address(swapRouter), 100e6);
        
        console.log("  Tokens minted to swap router");
        
        vm.stopBroadcast();
        
        // Print summary
        printSummary(
            address(poolManager),
            address(hook),
            address(oracle),
            address(ngn),
            address(usdc),
            PoolId.unwrap(poolKey.toId())
        );
    }
    
    function printSummary(
        address _poolManager,
        address _hook,
        address _oracle,
        address _ngn,
        address _usdc,
        bytes32 poolId
    ) internal view {
        console.log("\n=========================================================");
        console.log("         V4 POOL WITH HOOK - DEPLOYMENT SUMMARY");
        console.log("=========================================================");
        console.log("CORE CONTRACTS:");
        console.log("  PoolManager:    ", _poolManager);
        console.log("  Hook:           ", _hook);
        console.log("  Oracle:         ", _oracle);
        console.log("");
        console.log("TOKENS:");
        console.log("  NGN:            ", _ngn);
        console.log("  USDC:           ", _usdc);
        console.log("");
        console.log("POOL:");
        console.log("  Pool ID:        ", uint256(poolId));
        console.log("  Fee:            ", FEE / 100, "%");
        console.log("  Tick Spacing:   ", uint256(uint24(TICK_SPACING)));
        console.log("");
        console.log("ROUTERS:");
        console.log("  Liquidity:      ", address(modifyLiquidityRouter));
        console.log("  Swap:           ", address(swapRouter));
        console.log("=========================================================");
        console.log("\nThe pool is ready for swaps with street rate enforcement!");
    }
}
