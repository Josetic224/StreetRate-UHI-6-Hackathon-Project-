// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/ChainlinkStreetRateOracle.sol";
import "../src/StreetRateHookStandalone.sol";

contract DeployChainlinkOracle is Script {
    // Known Chainlink price feed addresses (examples - these would need to be verified)
    // Ethereum Mainnet examples:
    address constant ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address constant EUR_USD_FEED = 0xb49f677943BC038e9857d61E7d053CaA2C1734C1;
    
    // Polygon examples (more emerging market feeds available):
    address constant MATIC_USD_FEED_POLYGON = 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0;
    
    // For NGN/USD - would need custom feed or use a mock for demo
    // These are placeholder addresses that would need real feed addresses
    address constant NGN_USD_OFFICIAL_FEED = address(0); // Would need real feed
    address constant NGN_USD_STREET_FEED = address(0);   // Would need separate feed
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Chainlink oracle
        ChainlinkStreetRateOracle oracle = new ChainlinkStreetRateOracle();
        console.log("ChainlinkStreetRateOracle deployed at:", address(oracle));
        
        // For demo purposes, we'll show how to configure if we had real feeds
        // In production, you would use actual Chainlink feed addresses
        
        // Example configuration (would need real feed addresses):
        /*
        // Configure NGN/USDC if feeds existed
        if (NGN_USD_OFFICIAL_FEED != address(0)) {
            oracle.configurePriceFeed(
                address(0x1111), // NGN token address
                address(0x2222), // USDC token address
                NGN_USD_OFFICIAL_FEED,
                NGN_USD_STREET_FEED,
                false // Don't invert rate
            );
            console.log("Configured NGN/USDC pair");
        }
        */
        
        // Deploy hook with the Chainlink oracle
        StreetRateHookStandalone hook = new StreetRateHookStandalone(
            oracle,
            200 // 2% deviation threshold
        );
        console.log("StreetRateHook deployed at:", address(hook));
        
        vm.stopBroadcast();
        
        // Print deployment info
        console.log("\n=== Deployment Complete ===");
        console.log("Oracle:", address(oracle));
        console.log("Hook:", address(hook));
        console.log("\n=== Configuration Notes ===");
        console.log("To use with real Chainlink feeds:");
        console.log("1. Find appropriate price feeds on Chainlink documentation");
        console.log("2. Call configurePriceFeed() for each currency pair");
        console.log("3. For street rates, deploy custom feed or use secondary source");
        console.log("\n=== Example Chainlink Feeds ===");
        console.log("ETH/USD (Mainnet):", ETH_USD_FEED);
        console.log("EUR/USD (Mainnet):", EUR_USD_FEED);
        console.log("MATIC/USD (Polygon):", MATIC_USD_FEED_POLYGON);
    }
    
    /// @notice Helper function to demonstrate configuration with mock feeds for testing
    function configureWithMockFeeds(address oracle) public {
        // This would be called after deploying mock feeds for testing
        console.log("Configuring with mock feeds for testing...");
        
        // Deploy mock feeds (in test environment)
        // MockChainlinkFeed officialFeed = new MockChainlinkFeed(8, "NGN/USD Official");
        // MockChainlinkFeed streetFeed = new MockChainlinkFeed(8, "NGN/USD Street");
        
        // Configure the oracle
        // ChainlinkStreetRateOracle(oracle).configurePriceFeed(...);
    }
}

/// @notice Script to show how to use the oracle with existing deployment
contract ConfigureChainlinkOracle is Script {
    function run(address oracleAddress) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        ChainlinkStreetRateOracle oracle = ChainlinkStreetRateOracle(oracleAddress);
        
        // Example: Configure a new pair
        address base = address(0x1111);   // Token address
        address quote = address(0x2222);  // USDC address
        address officialFeed = address(0x3333); // Chainlink feed
        address streetFeed = address(0x4444);   // Custom feed for street rate
        
        oracle.configurePriceFeed(
            base,
            quote,
            officialFeed,
            streetFeed,
            false // Don't invert
        );
        
        console.log("Configured new pair:", base, "->", quote);
        
        // Update stale period if needed (e.g., for less liquid markets)
        oracle.updateStalePeriod(base, quote, 7200); // 2 hours
        
        vm.stopBroadcast();
    }
}
