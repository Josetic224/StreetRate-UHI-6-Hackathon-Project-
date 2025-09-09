// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/ChainlinkStreetRateOracle.sol";
import "../src/StreetRateHookStandalone.sol";
import "../src/interfaces/AggregatorV3Interface.sol";

/// @notice Mock Chainlink price feed for testing
contract MockChainlinkFeed is AggregatorV3Interface {
    uint8 public immutable override decimals;
    string public override description;
    uint256 public constant override version = 1;
    
    int256 private price;
    uint256 private updatedAt;
    uint80 private roundId;
    
    constructor(uint8 _decimals, string memory _description) {
        decimals = _decimals;
        description = _description;
        roundId = 1;
    }
    
    function setPrice(int256 _price) external {
        price = _price;
        updatedAt = block.timestamp;
        roundId++;
    }
    
    function setStalePrice(int256 _price, uint256 _staleness) external {
        price = _price;
        // Ensure we don't underflow
        if (block.timestamp > _staleness) {
            updatedAt = block.timestamp - _staleness;
        } else {
            updatedAt = 0;
        }
        roundId++;
    }
    
    function latestRoundData() external view override returns (
        uint80 _roundId,
        int256 _price,
        uint256 _startedAt,
        uint256 _updatedAt,
        uint80 _answeredInRound
    ) {
        return (roundId, price, updatedAt, updatedAt, roundId);
    }
    
    function getRoundData(uint80 _roundId) external view override returns (
        uint80 roundId_,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt_,
        uint80 answeredInRound
    ) {
        return (_roundId, price, updatedAt, updatedAt, _roundId);
    }
}

contract ChainlinkStreetRateOracleTest is Test {
    ChainlinkStreetRateOracle public oracle;
    StreetRateHookStandalone public hook;
    
    // Mock price feeds
    MockChainlinkFeed public ngnUsdOfficialFeed;
    MockChainlinkFeed public ngnUsdStreetFeed;
    MockChainlinkFeed public ghsUsdFeed;
    
    // Token addresses (mock)
    address public ngn = address(0x1111);
    address public usdc = address(0x2222);
    address public ghs = address(0x3333);
    
    // Events to test
    event FeedConfigured(
        address indexed base,
        address indexed quote,
        address officialFeed,
        address streetFeed,
        bool invertRate
    );
    
    event FeedUpdated(
        address indexed base,
        address indexed quote,
        uint256 officialRate,
        uint256 streetRate,
        uint256 timestamp
    );
    
    function setUp() public {
        // Deploy oracle
        oracle = new ChainlinkStreetRateOracle();
        
        // Deploy mock Chainlink feeds
        // NGN/USD feeds (8 decimals like real Chainlink)
        ngnUsdOfficialFeed = new MockChainlinkFeed(8, "NGN / USD Official");
        ngnUsdStreetFeed = new MockChainlinkFeed(8, "NGN / USD Street");
        
        // GHS/USD feed
        ghsUsdFeed = new MockChainlinkFeed(8, "GHS / USD");
        
        // Set initial prices
        // 1 USD = 1600 NGN official (so 1 NGN = 0.000625 USD)
        // Price feeds typically give USD per foreign currency
        ngnUsdOfficialFeed.setPrice(62500); // 0.000625 with 8 decimals
        ngnUsdStreetFeed.setPrice(60600);   // 0.000606 with 8 decimals (street rate)
        
        ghsUsdFeed.setPrice(8500000); // 0.085 USD per GHS with 8 decimals
    }
    
    function testConfigurePriceFeed() public {
        // Configure NGN/USDC pair
        vm.expectEmit(true, true, false, true);
        emit FeedConfigured(
            ngn,
            usdc,
            address(ngnUsdOfficialFeed),
            address(ngnUsdStreetFeed),
            false
        );
        
        oracle.configurePriceFeed(
            ngn,
            usdc,
            address(ngnUsdOfficialFeed),
            address(ngnUsdStreetFeed),
            false // Don't invert
        );
        
        // Verify configuration
        assertTrue(oracle.isPairSupported(ngn, usdc));
        
        ChainlinkStreetRateOracle.PriceFeedConfig memory config = oracle.getPairConfig(ngn, usdc);
        assertEq(config.officialFeed, address(ngnUsdOfficialFeed));
        assertEq(config.streetFeed, address(ngnUsdStreetFeed));
        assertEq(config.officialDecimals, 8);
        assertEq(config.streetDecimals, 8);
        assertTrue(config.isActive);
        assertFalse(config.invertRate);
    }
    
    function testGetRatesWithNormalization() public {
        // Configure NGN/USDC
        oracle.configurePriceFeed(
            ngn,
            usdc,
            address(ngnUsdOfficialFeed),
            address(ngnUsdStreetFeed),
            false
        );
        
        // Get rates (should be normalized to 18 decimals)
        uint256 officialRate = oracle.getOfficialRate(ngn, usdc);
        uint256 streetRate = oracle.getStreetRate(ngn, usdc);
        
        // Check normalization from 8 to 18 decimals
        // 0.000625 USD with 8 decimals = 62500
        // Should become 625000000000000 with 18 decimals
        assertEq(officialRate, 625000000000000);
        assertEq(streetRate, 606000000000000);
    }
    
    function testStalePrice() public {
        // Configure pair
        oracle.configurePriceFeed(
            ngn,
            usdc,
            address(ngnUsdOfficialFeed),
            address(ngnUsdStreetFeed),
            false
        );
        
        // Move time forward first
        vm.warp(block.timestamp + 10000);
        
        // Set stale price (2 hours old, exceeds default 1 hour)
        ngnUsdOfficialFeed.setStalePrice(62500, 7200);
        
        // Calculate expected updatedAt
        uint256 expectedUpdatedAt = block.timestamp > 7200 ? block.timestamp - 7200 : 0;
        
        // Should revert due to stale price
        vm.expectRevert(
            abi.encodeWithSelector(
                ChainlinkStreetRateOracle.StalePrice.selector,
                expectedUpdatedAt,
                3600
            )
        );
        oracle.getOfficialRate(ngn, usdc);
    }
    
    function testInvalidPrice() public {
        // Configure pair
        oracle.configurePriceFeed(
            ngn,
            usdc,
            address(ngnUsdOfficialFeed),
            address(ngnUsdStreetFeed),
            false
        );
        
        // Set invalid price (0 or negative)
        ngnUsdOfficialFeed.setPrice(0);
        
        // Should revert due to invalid price
        vm.expectRevert(ChainlinkStreetRateOracle.InvalidPrice.selector);
        oracle.getOfficialRate(ngn, usdc);
        
        // Test negative price
        ngnUsdOfficialFeed.setPrice(-100);
        vm.expectRevert(ChainlinkStreetRateOracle.InvalidPrice.selector);
        oracle.getOfficialRate(ngn, usdc);
    }
    
    function testUpdateStreetFeed() public {
        // Configure initial pair
        oracle.configurePriceFeed(
            ngn,
            usdc,
            address(ngnUsdOfficialFeed),
            address(ngnUsdStreetFeed),
            false
        );
        
        // Create new street feed with different rate
        MockChainlinkFeed newStreetFeed = new MockChainlinkFeed(8, "NGN / USD New Street");
        newStreetFeed.setPrice(58000); // More deviation
        
        // Update street feed
        oracle.updateStreetFeed(ngn, usdc, address(newStreetFeed));
        
        // Verify new rate
        uint256 streetRate = oracle.getStreetRate(ngn, usdc);
        assertEq(streetRate, 580000000000000); // 0.00058 with 18 decimals
    }
    
    function testGetRatesWithUpdate() public {
        // Configure pair
        oracle.configurePriceFeed(
            ngn,
            usdc,
            address(ngnUsdOfficialFeed),
            address(ngnUsdStreetFeed),
            false
        );
        
        // Get rates with update event
        vm.expectEmit(true, true, false, true);
        emit FeedUpdated(
            ngn,
            usdc,
            625000000000000,
            606000000000000,
            block.timestamp
        );
        
        (uint256 officialRate, uint256 streetRate) = oracle.getRatesWithUpdate(ngn, usdc);
        
        assertEq(officialRate, 625000000000000);
        assertEq(streetRate, 606000000000000);
    }
    
    function testIntegrationWithHook() public {
        // Configure oracle
        oracle.configurePriceFeed(
            ngn,
            usdc,
            address(ngnUsdOfficialFeed),
            address(ngnUsdStreetFeed),
            false
        );
        
        // Deploy hook with higher threshold since our test has ~3% deviation
        hook = new StreetRateHookStandalone(oracle, 400); // 4% threshold
        
        // Execute swap
        uint256 amountIn = 1000e18; // 1000 NGN
        uint256 amountOut = hook.executeSwap(ngn, usdc, amountIn, true);
        
        // Should use street rate: 1000 NGN * 0.000606 = 0.606 USDC
        uint256 expectedOut = (amountIn * 606000000000000) / 1e18;
        assertEq(amountOut, expectedOut);
    }
    
    function testMultiplePairs() public {
        // Configure NGN/USDC
        oracle.configurePriceFeed(
            ngn,
            usdc,
            address(ngnUsdOfficialFeed),
            address(ngnUsdStreetFeed),
            false
        );
        
        // Configure GHS/USDC (using same feed for official and street)
        oracle.configurePriceFeed(
            ghs,
            usdc,
            address(ghsUsdFeed),
            address(ghsUsdFeed), // Same feed for both
            false
        );
        
        // Test both pairs
        assertTrue(oracle.isPairSupported(ngn, usdc));
        assertTrue(oracle.isPairSupported(ghs, usdc));
        
        // Get rates for NGN
        uint256 ngnOfficial = oracle.getOfficialRate(ngn, usdc);
        uint256 ngnStreet = oracle.getStreetRate(ngn, usdc);
        assertEq(ngnOfficial, 625000000000000);
        assertEq(ngnStreet, 606000000000000);
        
        // Get rates for GHS (should be same for official and street)
        uint256 ghsRate = oracle.getOfficialRate(ghs, usdc);
        assertEq(ghsRate, 85000000000000000); // 0.085 with 18 decimals
        assertEq(oracle.getStreetRate(ghs, usdc), ghsRate);
    }
    
    function testOnlyOwnerModifiers() public {
        address notOwner = address(0x9999);
        
        vm.prank(notOwner);
        vm.expectRevert(ChainlinkStreetRateOracle.Unauthorized.selector);
        oracle.configurePriceFeed(
            ngn,
            usdc,
            address(ngnUsdOfficialFeed),
            address(ngnUsdStreetFeed),
            false
        );
        
        vm.prank(notOwner);
        vm.expectRevert(ChainlinkStreetRateOracle.Unauthorized.selector);
        oracle.updateStreetFeed(ngn, usdc, address(ngnUsdStreetFeed));
    }
    
    function testUpdateStalePeriod() public {
        // Configure pair
        oracle.configurePriceFeed(
            ngn,
            usdc,
            address(ngnUsdOfficialFeed),
            address(ngnUsdStreetFeed),
            false
        );
        
        // Move time forward first
        vm.warp(block.timestamp + 10000);
        
        // Update stale period to 2 hours
        oracle.updateStalePeriod(ngn, usdc, 7200);
        
        // Set price that's 1.5 hours old (would fail with default, passes with new)
        ngnUsdOfficialFeed.setStalePrice(62500, 5400);
        
        // Should work with new stale period
        uint256 rate = oracle.getOfficialRate(ngn, usdc);
        assertEq(rate, 625000000000000);
    }
}
