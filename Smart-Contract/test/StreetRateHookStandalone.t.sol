// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/StreetRateHookStandalone.sol";
import "../src/MockStreetRateOracle.sol";

contract StreetRateHookStandaloneTest is Test {
    StreetRateHookStandalone public hook;
    MockStreetRateOracle public oracle;
    
    // Test tokens
    address public ngn = address(0x1111);
    address public usdc = address(0x2222);
    address public ghs = address(0x3333);
    
    // Test users
    address public alice = address(0x4444);
    address public bob = address(0x5555);
    
    event RateChecked(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 officialRate,
        uint256 streetRate,
        uint256 appliedRate
    );
    
    event SwapExecuted(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    function setUp() public {
        // Deploy oracle
        oracle = new MockStreetRateOracle();
        
        // Deploy hook with 2% default threshold (200 basis points)
        hook = new StreetRateHookStandalone(oracle, 200);
        
        // Set default rates for NGN/USDC
        oracle.setDefaultNGNUSDCRates(ngn, usdc);
    }

    /// @notice Test 1: Swap at official rate (when official = street rate)
    function testSwapAtOfficialRate() public {
        // Set equal rates
        oracle.setRates(
            ngn,
            usdc,
            625000000000000, // 1 NGN = 0.000625 USDC
            625000000000000  // Same street rate
        );
        
        uint256 amountIn = 1000e18; // 1000 NGN
        
        // Execute swap
        vm.prank(alice);
        uint256 amountOut = hook.executeSwap(ngn, usdc, amountIn, true);
        
        // Expected output: 1000 NGN * 0.000625 = 0.625 USDC (625000000000000000)
        uint256 expectedOut = (amountIn * 625000000000000) / 1e18;
        assertEq(amountOut, expectedOut, "Output amount mismatch");
    }

    /// @notice Test 2: Swap at street rate (applied when different from official)
    function testSwapAtStreetRate() public {
        // Street rate is 1.5% better (within 2% threshold)
        oracle.setRates(
            ngn,
            usdc,
            625000000000000,   // Official: 1 NGN = 0.000625 USDC
            634375000000000    // Street: 1 NGN = 0.000634375 USDC (1.5% better)
        );
        
        uint256 amountIn = 1000e18; // 1000 NGN
        
        // Expect rate checked event
        vm.expectEmit(true, true, false, true);
        emit RateChecked(ngn, usdc, 625000000000000, 634375000000000, 634375000000000);
        
        // Execute swap
        vm.prank(alice);
        uint256 amountOut = hook.executeSwap(ngn, usdc, amountIn, true);
        
        // Expected output using street rate
        uint256 expectedOut = (amountIn * 634375000000000) / 1e18;
        assertEq(amountOut, expectedOut, "Should use street rate");
        
        // Verify user gets more USDC due to better street rate
        uint256 officialOut = (amountIn * 625000000000000) / 1e18;
        assertGt(amountOut, officialOut, "Street rate should give more output");
    }

    /// @notice Test 3: Revert when deviation exceeds threshold
    function testRevertOnHighDeviation() public {
        // Set street rate 5% better (exceeds 2% threshold)
        oracle.setRates(
            ngn,
            usdc,
            625000000000000,   // Official: 1 NGN = 0.000625 USDC
            656250000000000    // Street: 1 NGN = 0.00065625 USDC (5% better)
        );
        
        uint256 amountIn = 1000e18; // 1000 NGN
        
        // Should revert with RateDeviationExceeded
        vm.expectRevert(
            abi.encodeWithSelector(
                StreetRateHookStandalone.RateDeviationExceeded.selector,
                625000000000000,
                656250000000000,
                500, // 5% in basis points
                200  // 2% threshold
            )
        );
        
        vm.prank(alice);
        hook.executeSwap(ngn, usdc, amountIn, true);
    }

    /// @notice Test 4: Configurable threshold works
    function testConfigurableThreshold() public {
        // Update threshold to 5% (500 basis points)
        hook.updateDeviationThreshold(500);
        assertEq(hook.deviationThreshold(), 500);
        
        // Set street rate 4% better (within new 5% threshold)
        oracle.setRates(
            ngn,
            usdc,
            625000000000000,   // Official: 1 NGN = 0.000625 USDC
            650000000000000    // Street: 1 NGN = 0.00065 USDC (4% better)
        );
        
        uint256 amountIn = 1000e18; // 1000 NGN
        
        // Should not revert with 4% deviation when threshold is 5%
        vm.prank(alice);
        uint256 amountOut = hook.executeSwap(ngn, usdc, amountIn, true);
        
        // Verify output uses street rate
        uint256 expectedOut = (amountIn * 650000000000000) / 1e18;
        assertEq(amountOut, expectedOut, "Should use street rate");
    }
    
    /// @notice Test 5: Unsupported pair reverts
    function testUnsupportedPair() public {
        address randomToken = address(0x9999);
        
        // Should revert with UnsupportedPair
        vm.expectRevert(
            abi.encodeWithSelector(
                StreetRateHookStandalone.UnsupportedPair.selector,
                randomToken,
                usdc
            )
        );
        
        vm.prank(alice);
        hook.executeSwap(randomToken, usdc, 1000e18, true);
    }
    
    /// @notice Test 6: Oracle update (admin only)
    function testOracleUpdate() public {
        MockStreetRateOracle newOracle = new MockStreetRateOracle();
        
        // Non-owner cannot update
        vm.prank(alice);
        vm.expectRevert("Only owner");
        hook.updateOracle(newOracle);
        
        // Owner can update
        hook.updateOracle(newOracle);
        assertEq(address(hook.oracle()), address(newOracle));
    }
    
    /// @notice Test 7: Multiple currency pairs
    function testMultipleCurrencyPairs() public {
        // Set rates for GHS/USDC
        oracle.setRates(
            ghs,
            usdc,
            85000000000000000,  // Official: 1 GHS = 0.085 USDC
            83300000000000000   // Street: 1 GHS = 0.0833 USDC (2% deviation)
        );
        
        // Set rates for NGN/USDC
        oracle.setRates(
            ngn,
            usdc,
            625000000000000,   // Official: 1 NGN = 0.000625 USDC
            612500000000000    // Street: 1 NGN = 0.0006125 USDC (2% deviation)
        );
        
        // Test NGN/USDC swap
        vm.prank(alice);
        uint256 ngnOut = hook.executeSwap(ngn, usdc, 1000e18, true);
        assertEq(ngnOut, (1000e18 * 612500000000000) / 1e18);
        
        // Test GHS/USDC swap
        vm.prank(bob);
        uint256 ghsOut = hook.executeSwap(ghs, usdc, 100e18, true);
        assertEq(ghsOut, (100e18 * 83300000000000000) / 1e18);
    }
    
    /// @notice Test 8: Preview swap functionality
    function testPreviewSwap() public {
        oracle.setRates(
            ngn,
            usdc,
            625000000000000,   // Official
            634375000000000    // Street (1.5% better)
        );
        
        (bool wouldSucceed, uint256 expectedOut, uint256 appliedRate) = 
            hook.previewSwap(ngn, usdc, 1000e18);
        
        assertTrue(wouldSucceed, "Swap should succeed");
        assertEq(expectedOut, (1000e18 * 634375000000000) / 1e18);
        assertEq(appliedRate, 634375000000000);
        
        // Test preview with excessive deviation
        oracle.setRates(
            ngn,
            usdc,
            625000000000000,   // Official
            700000000000000    // Street (12% better - will fail)
        );
        
        (wouldSucceed, , ) = hook.previewSwap(ngn, usdc, 1000e18);
        assertFalse(wouldSucceed, "Swap should fail due to high deviation");
    }
    
    /// @notice Test 9: Event emissions
    function testEventEmissions() public {
        oracle.setRates(ngn, usdc, 625000000000000, 634375000000000);
        
        uint256 amountIn = 1000e18;
        uint256 expectedOut = (amountIn * 634375000000000) / 1e18;
        
        // Check RateChecked event
        vm.expectEmit(true, true, false, true);
        emit RateChecked(ngn, usdc, 625000000000000, 634375000000000, 634375000000000);
        
        // Check SwapExecuted event
        vm.expectEmit(true, true, true, true);
        emit SwapExecuted(alice, ngn, usdc, amountIn, expectedOut);
        
        vm.prank(alice);
        hook.executeSwap(ngn, usdc, amountIn, true);
    }
    
    /// @notice Test 10: Edge cases
    function testEdgeCases() public {
        // Test with exact 2% deviation (should pass)
        oracle.setRates(
            ngn,
            usdc,
            625000000000000,   // Official
            637500000000000    // Exactly 2% better
        );
        
        vm.prank(alice);
        uint256 amountOut = hook.executeSwap(ngn, usdc, 1000e18, true);
        assertGt(amountOut, 0, "Should succeed with exact threshold");
        
        // Test with 2.01% deviation (should fail)
        oracle.setRates(
            ngn,
            usdc,
            625000000000000,   // Official
            637562500000000    // 2.01% better
        );
        
        vm.expectRevert();
        vm.prank(alice);
        hook.executeSwap(ngn, usdc, 1000e18, true);
    }
}
