// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/HybridRateOracle.sol";
import "../src/StreetRateHookStandalone.sol";
import "../src/tokens/FiatTokens.sol";

contract HybridRateOracleTest is Test {
    HybridRateOracle public oracle;
    StreetRateHookStandalone public hook;
    
    // Fiat tokens
    NGNToken public ngn;
    ARSToken public ars;
    GHSToken public ghs;
    USDCMock public usdc;
    
    // Test addresses
    address public alice = address(0x1);
    address public bob = address(0x2);
    
    // Events to test
    event RatesConfigured(
        address indexed base,
        address indexed quote,
        uint256 officialRate,
        uint256 streetRate,
        string currencyCode,
        string countryFlag
    );
    
    event RatesUpdated(
        address indexed base,
        address indexed quote,
        uint256 oldOfficialRate,
        uint256 newOfficialRate,
        uint256 oldStreetRate,
        uint256 newStreetRate
    );
    
    function setUp() public {
        // Deploy tokens
        ngn = new NGNToken();
        ars = new ARSToken();
        ghs = new GHSToken();
        usdc = new USDCMock();
        
        // Deploy oracle
        oracle = new HybridRateOracle();
        
        // Initialize with default rates
        oracle.initializeDefaultRates(
            address(ngn),
            address(ars),
            address(ghs),
            address(usdc)
        );
        
        // Deploy hook with 70% deviation threshold for testing (to accommodate ARS)
        hook = new StreetRateHookStandalone(oracle, 7000);
        
        // Mint tokens to test users
        ngn.mint(alice, 1000000e18);
        ars.mint(alice, 1000000e18);
        ghs.mint(alice, 1000000e18);
        usdc.mint(alice, 100000e6);
        
        ngn.mint(bob, 1000000e18);
        ars.mint(bob, 1000000e18);
        ghs.mint(bob, 1000000e18);
        usdc.mint(bob, 100000e6);
    }
    
    function testInitialRates() public {
        // Test NGN/USDC
        assertTrue(oracle.isPairSupported(address(ngn), address(usdc)));
        assertEq(oracle.getOfficialRate(address(ngn), address(usdc)), 1250000000000000);
        assertEq(oracle.getStreetRate(address(ngn), address(usdc)), 667000000000000);
        
        // Test ARS/USDC
        assertTrue(oracle.isPairSupported(address(ars), address(usdc)));
        assertEq(oracle.getOfficialRate(address(ars), address(usdc)), 2860000000000000);
        assertEq(oracle.getStreetRate(address(ars), address(usdc)), 1000000000000000);
        
        // Test GHS/USDC
        assertTrue(oracle.isPairSupported(address(ghs), address(usdc)));
        assertEq(oracle.getOfficialRate(address(ghs), address(usdc)), 83300000000000000);
        assertEq(oracle.getStreetRate(address(ghs), address(usdc)), 66700000000000000);
    }
    
    function testGetRatePair() public {
        HybridRateOracle.RatePair memory ngnPair = oracle.getRatePair(address(ngn), address(usdc));
        
        assertEq(ngnPair.officialRate, 1250000000000000);
        assertEq(ngnPair.streetRate, 667000000000000);
        assertTrue(ngnPair.isSupported);
        assertEq(ngnPair.currencyCode, "NGN");
        assertEq(ngnPair.countryFlag, unicode"🇳🇬");
    }
    
    function testGetSupportedCurrencies() public {
        address[] memory currencies = oracle.getSupportedCurrencies();
        assertEq(currencies.length, 3);
        assertEq(currencies[0], address(ngn));
        assertEq(currencies[1], address(ars));
        assertEq(currencies[2], address(ghs));
    }
    
    function testGetDeviation() public {
        // NGN deviation: (1250000000000000 - 667000000000000) / 1250000000000000 * 10000
        // = 583000000000000 / 1250000000000000 * 10000 = 4664 basis points (46.64%)
        uint256 ngnDeviation = oracle.getDeviation(address(ngn), address(usdc));
        assertEq(ngnDeviation, 4664);
        
        // ARS deviation: (2860000000000000 - 1000000000000000) / 2860000000000000 * 10000
        // = 1860000000000000 / 2860000000000000 * 10000 = 6503 basis points (65.03%)
        uint256 arsDeviation = oracle.getDeviation(address(ars), address(usdc));
        assertEq(arsDeviation, 6503);
        
        // GHS deviation: (83300000000000000 - 66700000000000000) / 83300000000000000 * 10000
        // = 16600000000000000 / 83300000000000000 * 10000 = 1992 basis points (19.92%)
        uint256 ghsDeviation = oracle.getDeviation(address(ghs), address(usdc));
        assertEq(ghsDeviation, 1992);
    }
    
    function testUpdateRates() public {
        uint256 oldOfficial = oracle.getOfficialRate(address(ngn), address(usdc));
        uint256 oldStreet = oracle.getStreetRate(address(ngn), address(usdc));
        
        uint256 newOfficial = 1300000000000000;
        uint256 newStreet = 600000000000000;
        
        vm.expectEmit(true, true, false, true);
        emit RatesUpdated(
            address(ngn),
            address(usdc),
            oldOfficial,
            newOfficial,
            oldStreet,
            newStreet
        );
        
        oracle.updateRates(address(ngn), address(usdc), newOfficial, newStreet);
        
        assertEq(oracle.getOfficialRate(address(ngn), address(usdc)), newOfficial);
        assertEq(oracle.getStreetRate(address(ngn), address(usdc)), newStreet);
    }
    
    function testConfigureNewPair() public {
        address newToken = address(0x9999);
        
        vm.expectEmit(true, true, false, true);
        emit RatesConfigured(
            newToken,
            address(usdc),
            5000000000000000,
            4000000000000000,
            "TEST",
            unicode"🏴"
        );
        
        oracle.configureRates(
            newToken,
            address(usdc),
            5000000000000000,
            4000000000000000,
            "TEST",
            unicode"🏴"
        );
        
        assertTrue(oracle.isPairSupported(newToken, address(usdc)));
        assertEq(oracle.getSupportedCurrencies().length, 4);
    }
    
    function testBatchConfigureRates() public {
        address[] memory bases = new address[](2);
        bases[0] = address(0x7777);
        bases[1] = address(0x8888);
        
        uint256[] memory officialRates = new uint256[](2);
        officialRates[0] = 1000000000000000;
        officialRates[1] = 2000000000000000;
        
        uint256[] memory streetRates = new uint256[](2);
        streetRates[0] = 900000000000000;
        streetRates[1] = 1800000000000000;
        
        string[] memory codes = new string[](2);
        codes[0] = "XXX";
        codes[1] = "YYY";
        
        string[] memory flags = new string[](2);
        flags[0] = unicode"🏳️";
        flags[1] = unicode"🏴";
        
        oracle.batchConfigureRates(
            bases,
            address(usdc),
            officialRates,
            streetRates,
            codes,
            flags
        );
        
        assertTrue(oracle.isPairSupported(bases[0], address(usdc)));
        assertTrue(oracle.isPairSupported(bases[1], address(usdc)));
        assertEq(oracle.getSupportedCurrencies().length, 5);
    }
    
    function testSwapNGNToUSDC() public {
        uint256 amountIn = 10000e18; // 10,000 NGN
        
        vm.prank(alice);
        uint256 amountOut = hook.executeSwap(
            address(ngn),
            address(usdc),
            amountIn,
            true
        );
        
        // Should use street rate: 10,000 NGN * 0.000667 = 6.67 USDC
        uint256 expectedOut = (amountIn * 667000000000000) / 1e18;
        assertEq(amountOut, expectedOut);
        assertEq(amountOut, 6670000000000000000); // 6.67 USDC (with 18 decimals)
    }
    
    function testSwapARSToUSDC() public {
        uint256 amountIn = 5000e18; // 5,000 ARS
        
        vm.prank(alice);
        uint256 amountOut = hook.executeSwap(
            address(ars),
            address(usdc),
            amountIn,
            true
        );
        
        // Should use street rate: 5,000 ARS * 0.001 = 5 USDC
        uint256 expectedOut = (amountIn * 1000000000000000) / 1e18;
        assertEq(amountOut, expectedOut);
        assertEq(amountOut, 5000000000000000000); // 5 USDC (with 18 decimals)
    }
    
    function testSwapGHSToUSDC() public {
        uint256 amountIn = 100e18; // 100 GHS
        
        vm.prank(alice);
        uint256 amountOut = hook.executeSwap(
            address(ghs),
            address(usdc),
            amountIn,
            true
        );
        
        // Should use street rate: 100 GHS * 0.0667 = 6.67 USDC
        uint256 expectedOut = (amountIn * 66700000000000000) / 1e18;
        assertEq(amountOut, expectedOut);
        assertEq(amountOut, 6670000000000000000); // 6.67 USDC (with 18 decimals)
    }
    
    function testRevertOnExcessiveDeviation() public {
        // Create a hook with only 10% deviation tolerance
        StreetRateHookStandalone strictHook = new StreetRateHookStandalone(oracle, 1000);
        
        // NGN has 46.64% deviation, should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                StreetRateHookStandalone.RateDeviationExceeded.selector,
                1250000000000000,
                667000000000000,
                4664,
                1000
            )
        );
        
        vm.prank(alice);
        strictHook.executeSwap(address(ngn), address(usdc), 1000e18, true);
    }
    
    function testMultiplePairsInSequence() public {
        // Test that multiple pairs work independently
        vm.startPrank(alice);
        
        // Swap NGN
        uint256 ngnOut = hook.executeSwap(address(ngn), address(usdc), 1000e18, true);
        assertGt(ngnOut, 0);
        
        // Swap ARS
        uint256 arsOut = hook.executeSwap(address(ars), address(usdc), 1000e18, true);
        assertGt(arsOut, 0);
        
        // Swap GHS
        uint256 ghsOut = hook.executeSwap(address(ghs), address(usdc), 100e18, true);
        assertGt(ghsOut, 0);
        
        vm.stopPrank();
        
        // Verify different rates were applied
        assertNotEq(ngnOut, arsOut); // Different currencies should have different outputs
    }
    
    function testOnlyOwnerCanUpdateRates() public {
        vm.prank(alice);
        vm.expectRevert("Only owner");
        oracle.updateRates(address(ngn), address(usdc), 1000000000000000, 900000000000000);
        
        vm.prank(bob);
        vm.expectRevert("Only owner");
        oracle.configureRates(
            address(0x9999),
            address(usdc),
            1000000000000000,
            900000000000000,
            "TEST",
            unicode"🏴"
        );
    }
    
    function testUnsupportedPairReverts() public {
        address unsupportedToken = address(0xDEAD);
        
        vm.expectRevert("Pair not supported");
        oracle.getOfficialRate(unsupportedToken, address(usdc));
        
        vm.expectRevert("Pair not supported");
        oracle.getStreetRate(unsupportedToken, address(usdc));
        
        vm.expectRevert(
            abi.encodeWithSelector(
                StreetRateHookStandalone.UnsupportedPair.selector,
                unsupportedToken,
                address(usdc)
            )
        );
        vm.prank(alice);
        hook.executeSwap(unsupportedToken, address(usdc), 1000e18, true);
    }
    
    function testGetCurrencyCount() public {
        assertEq(oracle.getCurrencyCount(), 3);
        
        // Add a new currency
        oracle.configureRates(
            address(0x9999),
            address(usdc),
            1000000000000000,
            900000000000000,
            "NEW",
            unicode"🆕"
        );
        
        assertEq(oracle.getCurrencyCount(), 4);
    }
}
