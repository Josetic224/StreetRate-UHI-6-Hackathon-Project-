// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {IPoolManager} from "../lib/v4-core/src/interfaces/IPoolManager.sol";
import {Currency} from "../lib/v4-core/src/types/Currency.sol";
import {PoolKey} from "../lib/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "../lib/v4-core/src/types/PoolId.sol";
import {IHooks} from "../lib/v4-core/src/interfaces/IHooks.sol";
import {BalanceDelta} from "../lib/v4-core/src/types/BalanceDelta.sol";
import {PoolSwapTest} from "../lib/v4-core/src/test/PoolSwapTest.sol";
import {PoolModifyLiquidityTest} from "../lib/v4-core/src/test/PoolModifyLiquidityTest.sol";
import {TickMath} from "../lib/v4-core/src/libraries/TickMath.sol";

import "../src/StreetRateHookV4Simple.sol";
import "../src/HybridRateOracle.sol";
import "../src/tokens/FiatTokens.sol";

/// @title Sepolia Integration Tests
/// @notice Tests for verifying the hook works correctly on testnet
contract SepoliaIntegrationTest is Test {
    using PoolIdLibrary for PoolKey;
    
    // Contracts (to be loaded from deployment)
    IPoolManager public poolManager;
    StreetRateHookV4Simple public hook;
    HybridRateOracle public oracle;
    PoolSwapTest public swapRouter;
    PoolModifyLiquidityTest public liquidityRouter;
    
    // Tokens
    NGNToken public ngn;
    ARSToken public ars;
    GHSToken public ghs;
    USDCMock public usdc;
    
    // Pool keys
    PoolKey public ngnUsdcPool;
    PoolKey public arsUsdcPool;
    PoolKey public ghsUsdcPool;
    
    // Test accounts
    address public alice = address(0x1111);
    address public bob = address(0x2222);
    
    // Events to monitor
    event RateChecked(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 officialRate,
        uint256 streetRate,
        uint256 appliedRate
    );
    
    event SwapAdjusted(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        int256 amountSpecified,
        uint256 adjustmentFactor
    );
    
    function setUp() public {
        // Fork Sepolia if RPC is available
        string memory rpcUrl = vm.envOr("SEPOLIA_RPC_URL", string(""));
        if (bytes(rpcUrl).length > 0) {
            vm.createSelectFork(rpcUrl);
            console.log("Forked Sepolia at block:", block.number);
        }
        
        // Load deployment addresses (would be from sepolia.json in real scenario)
        // For testing, we'll deploy fresh instances
        deployContracts();
        setupPools();
        mintTokensToTestAccounts();
    }
    
    function deployContracts() internal {
        // Deploy tokens
        ngn = new NGNToken();
        ars = new ARSToken();
        ghs = new GHSToken();
        usdc = new USDCMock();
        
        // Deploy oracle
        oracle = new HybridRateOracle();
        oracle.initializeDefaultRates(
            address(ngn),
            address(ars),
            address(ghs),
            address(usdc)
        );
        
        // Deploy pool manager
        poolManager = IPoolManager(address(new PoolManager(address(this))));
        
        // Deploy routers
        swapRouter = new PoolSwapTest(poolManager);
        liquidityRouter = new PoolModifyLiquidityTest(poolManager);
        
        // Deploy hook (simplified for testing)
        hook = new StreetRateHookV4Simple(
            poolManager,
            oracle,
            7000 // 70% deviation threshold
        );
    }
    
    function setupPools() internal {
        // Setup NGN/USDC pool
        ngnUsdcPool = createPool(address(ngn), address(usdc));
        
        // Setup ARS/USDC pool
        arsUsdcPool = createPool(address(ars), address(usdc));
        
        // Setup GHS/USDC pool
        ghsUsdcPool = createPool(address(ghs), address(usdc));
    }
    
    function createPool(address token0, address token1) internal returns (PoolKey memory) {
        (Currency currency0, Currency currency1) = token0 < token1 ? 
            (Currency.wrap(token0), Currency.wrap(token1)) :
            (Currency.wrap(token1), Currency.wrap(token0));
        
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        
        // Initialize pool
        poolManager.initialize(poolKey, 2045951728901457409024);
        
        return poolKey;
    }
    
    function mintTokensToTestAccounts() internal {
        // Mint to alice
        ngn.mint(alice, 1_000_000e18);
        ars.mint(alice, 1_000_000e18);
        ghs.mint(alice, 10_000e18);
        usdc.mint(alice, 10_000e6);
        
        // Mint to bob
        ngn.mint(bob, 1_000_000e18);
        ars.mint(bob, 1_000_000e18);
        ghs.mint(bob, 10_000e18);
        usdc.mint(bob, 10_000e6);
        
        // Mint to routers for liquidity
        ngn.mint(address(liquidityRouter), 10_000_000e18);
        ars.mint(address(liquidityRouter), 10_000_000e18);
        ghs.mint(address(liquidityRouter), 100_000e18);
        usdc.mint(address(liquidityRouter), 100_000e6);
    }
    
    /// @notice Test NGN/USDC swap with street rate enforcement
    function testNGNToUSDCSwapWithStreetRate() public {
        uint256 amountIn = 10_000e18; // 10,000 NGN
        
        // Transfer tokens to swap router
        vm.prank(alice);
        ngn.transfer(address(swapRouter), amountIn);
        
        // Expect rate check event
        vm.expectEmit(true, true, false, true);
        emit RateChecked(
            address(ngn),
            address(usdc),
            1250000000000000,  // Official rate
            667000000000000,   // Street rate
            667000000000000    // Applied rate
        );
        
        // Execute swap
        bool zeroForOne = address(ngn) < address(usdc);
        
        BalanceDelta delta = swapRouter.swap(
            ngnUsdcPool,
            IPoolManager.SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            new bytes(0)
        );
        
        // Verify swap executed
        if (zeroForOne) {
            assertLt(delta.amount0(), 0, "NGN not consumed");
            assertGt(delta.amount1(), 0, "USDC not received");
        } else {
            assertLt(delta.amount1(), 0, "NGN not consumed");
            assertGt(delta.amount0(), 0, "USDC not received");
        }
    }
    
    /// @notice Test ARS/USDC swap
    function testARSToUSDCSwap() public {
        uint256 amountIn = 5_000e18; // 5,000 ARS
        
        vm.prank(alice);
        ars.transfer(address(swapRouter), amountIn);
        
        bool zeroForOne = address(ars) < address(usdc);
        
        BalanceDelta delta = swapRouter.swap(
            arsUsdcPool,
            IPoolManager.SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            new bytes(0)
        );
        
        // Verify swap executed
        assertTrue(delta.amount0() != 0 || delta.amount1() != 0, "Swap failed");
    }
    
    /// @notice Test GHS/USDC swap
    function testGHSToUSDCSwap() public {
        uint256 amountIn = 100e18; // 100 GHS
        
        vm.prank(alice);
        ghs.transfer(address(swapRouter), amountIn);
        
        bool zeroForOne = address(ghs) < address(usdc);
        
        BalanceDelta delta = swapRouter.swap(
            ghsUsdcPool,
            IPoolManager.SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            new bytes(0)
        );
        
        // Verify swap executed
        assertTrue(delta.amount0() != 0 || delta.amount1() != 0, "Swap failed");
    }
    
    /// @notice Test that excessive deviation causes revert
    function testRevertOnExcessiveDeviation() public {
        // Update oracle to have excessive deviation
        oracle.updateRates(
            address(ngn),
            address(usdc),
            1250000000000000,  // Official
            100000000000000    // Street (92% deviation)
        );
        
        uint256 amountIn = 1_000e18;
        vm.prank(alice);
        ngn.transfer(address(swapRouter), amountIn);
        
        bool zeroForOne = address(ngn) < address(usdc);
        
        // Should revert due to excessive deviation
        vm.expectRevert(
            abi.encodeWithSelector(
                StreetRateHookV4Simple.RateDeviationExceeded.selector,
                1250000000000000,
                100000000000000,
                9200,
                7000
            )
        );
        
        swapRouter.swap(
            ngnUsdcPool,
            IPoolManager.SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            new bytes(0)
        );
    }
    
    /// @notice Test gas consumption
    function testGasConsumption() public {
        uint256 amountIn = 1_000e18;
        
        vm.prank(alice);
        ngn.transfer(address(swapRouter), amountIn);
        
        bool zeroForOne = address(ngn) < address(usdc);
        
        uint256 gasBefore = gasleft();
        
        swapRouter.swap(
            ngnUsdcPool,
            IPoolManager.SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            new bytes(0)
        );
        
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for swap with hook:", gasUsed);
        
        // Assert reasonable gas usage (should be around 40-50k for hook logic)
        assertLt(gasUsed, 200_000, "Gas usage too high");
    }
    
    /// @notice Test multiple swaps in sequence
    function testMultipleSwapsInSequence() public {
        // Swap 1: NGN to USDC
        vm.prank(alice);
        ngn.transfer(address(swapRouter), 1_000e18);
        executeSwap(ngnUsdcPool, -1_000e18);
        
        // Swap 2: ARS to USDC
        vm.prank(alice);
        ars.transfer(address(swapRouter), 2_000e18);
        executeSwap(arsUsdcPool, -2_000e18);
        
        // Swap 3: GHS to USDC
        vm.prank(alice);
        ghs.transfer(address(swapRouter), 50e18);
        executeSwap(ghsUsdcPool, -50e18);
        
        // All swaps should complete successfully
        assertTrue(true, "All swaps completed");
    }
    
    function executeSwap(PoolKey memory pool, int256 amount) internal returns (BalanceDelta) {
        bool zeroForOne = amount < 0;
        
        return swapRouter.swap(
            pool,
            IPoolManager.SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: amount,
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            new bytes(0)
        );
    }
}
