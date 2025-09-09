// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IStreetRateOracle.sol";
import "./interfaces/AggregatorV3Interface.sol";

/// @title ChainlinkStreetRateOracle
/// @notice Live oracle adapter that uses Chainlink price feeds for official rates
///         and allows configurable feeds for street rates
contract ChainlinkStreetRateOracle is IStreetRateOracle {
    /// @notice Structure to hold price feed configuration for a currency pair
    struct PriceFeedConfig {
        address officialFeed;    // Chainlink feed for official rate
        address streetFeed;      // Separate feed for street rate (can be same as official)
        uint8 officialDecimals;  // Decimals of official feed
        uint8 streetDecimals;    // Decimals of street feed
        bool isActive;           // Whether this pair is active
        bool invertRate;         // Whether to invert the rate (for reverse pairs)
        uint256 stalePeriod;     // Max age of price data in seconds (default 3600)
    }
    
    /// @notice Mapping from base => quote => price feed configuration
    mapping(address => mapping(address => PriceFeedConfig)) public priceFeeds;
    
    /// @notice Admin/owner of the oracle
    address public immutable owner;
    
    /// @notice Default stale period (1 hour)
    uint256 public constant DEFAULT_STALE_PERIOD = 3600;
    
    /// @notice Target decimals for all rates
    uint256 public constant TARGET_DECIMALS = 18;
    
    /// @notice Events
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
    
    event StalePeriodUpdated(address indexed base, address indexed quote, uint256 stalePeriod);
    
    /// @notice Custom errors
    error Unauthorized();
    error InvalidFeedAddress();
    error StalePrice(uint256 updatedAt, uint256 stalePeriod);
    error InvalidPrice();
    error PairNotConfigured(address base, address quote);
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /// @notice Configures price feeds for a currency pair
    /// @param base The base currency address
    /// @param quote The quote currency address
    /// @param officialFeed The Chainlink feed address for official rate
    /// @param streetFeed The feed address for street rate (can be same as official)
    /// @param invertRate Whether to invert the rate (1/price)
    function configurePriceFeed(
        address base,
        address quote,
        address officialFeed,
        address streetFeed,
        bool invertRate
    ) external onlyOwner {
        if (officialFeed == address(0) || streetFeed == address(0)) {
            revert InvalidFeedAddress();
        }
        
        // Get decimals from feeds
        uint8 officialDecimals = AggregatorV3Interface(officialFeed).decimals();
        uint8 streetDecimals = AggregatorV3Interface(streetFeed).decimals();
        
        priceFeeds[base][quote] = PriceFeedConfig({
            officialFeed: officialFeed,
            streetFeed: streetFeed,
            officialDecimals: officialDecimals,
            streetDecimals: streetDecimals,
            isActive: true,
            invertRate: invertRate,
            stalePeriod: DEFAULT_STALE_PERIOD
        });
        
        emit FeedConfigured(base, quote, officialFeed, streetFeed, invertRate);
    }
    
    /// @notice Updates the stale period for a currency pair
    /// @param base The base currency address
    /// @param quote The quote currency address
    /// @param stalePeriod The new stale period in seconds
    function updateStalePeriod(
        address base,
        address quote,
        uint256 stalePeriod
    ) external onlyOwner {
        PriceFeedConfig storage config = priceFeeds[base][quote];
        if (!config.isActive) revert PairNotConfigured(base, quote);
        
        config.stalePeriod = stalePeriod;
        emit StalePeriodUpdated(base, quote, stalePeriod);
    }
    
    /// @notice Updates only the street feed for a pair (useful for testing)
    /// @param base The base currency address
    /// @param quote The quote currency address
    /// @param newStreetFeed The new street feed address
    function updateStreetFeed(
        address base,
        address quote,
        address newStreetFeed
    ) external onlyOwner {
        if (newStreetFeed == address(0)) revert InvalidFeedAddress();
        
        PriceFeedConfig storage config = priceFeeds[base][quote];
        if (!config.isActive) revert PairNotConfigured(base, quote);
        
        config.streetFeed = newStreetFeed;
        config.streetDecimals = AggregatorV3Interface(newStreetFeed).decimals();
        
        emit FeedConfigured(base, quote, config.officialFeed, newStreetFeed, config.invertRate);
    }
    
    /// @inheritdoc IStreetRateOracle
    function getOfficialRate(address base, address quote) external view override returns (uint256) {
        PriceFeedConfig memory config = priceFeeds[base][quote];
        if (!config.isActive) revert PairNotConfigured(base, quote);
        
        uint256 rate = _getPriceFromFeed(
            config.officialFeed,
            config.officialDecimals,
            config.stalePeriod
        );
        
        // Apply inversion if needed
        if (config.invertRate) {
            rate = (10 ** (TARGET_DECIMALS * 2)) / rate;
        }
        
        return rate;
    }
    
    /// @inheritdoc IStreetRateOracle
    function getStreetRate(address base, address quote) external view override returns (uint256) {
        PriceFeedConfig memory config = priceFeeds[base][quote];
        if (!config.isActive) revert PairNotConfigured(base, quote);
        
        uint256 rate = _getPriceFromFeed(
            config.streetFeed,
            config.streetDecimals,
            config.stalePeriod
        );
        
        // Apply inversion if needed
        if (config.invertRate) {
            rate = (10 ** (TARGET_DECIMALS * 2)) / rate;
        }
        
        return rate;
    }
    
    /// @inheritdoc IStreetRateOracle
    function isPairSupported(address base, address quote) external view override returns (bool) {
        return priceFeeds[base][quote].isActive;
    }
    
    /// @notice Gets both rates and emits an update event
    /// @param base The base currency address
    /// @param quote The quote currency address
    /// @return officialRate The official exchange rate
    /// @return streetRate The street exchange rate
    function getRatesWithUpdate(address base, address quote) 
        external 
        returns (uint256 officialRate, uint256 streetRate) 
    {
        PriceFeedConfig memory config = priceFeeds[base][quote];
        if (!config.isActive) revert PairNotConfigured(base, quote);
        
        officialRate = _getPriceFromFeed(
            config.officialFeed,
            config.officialDecimals,
            config.stalePeriod
        );
        
        streetRate = _getPriceFromFeed(
            config.streetFeed,
            config.streetDecimals,
            config.stalePeriod
        );
        
        // Apply inversion if needed
        if (config.invertRate) {
            officialRate = (10 ** (TARGET_DECIMALS * 2)) / officialRate;
            streetRate = (10 ** (TARGET_DECIMALS * 2)) / streetRate;
        }
        
        emit FeedUpdated(base, quote, officialRate, streetRate, block.timestamp);
        
        return (officialRate, streetRate);
    }
    
    /// @notice Internal function to get price from a Chainlink feed
    /// @param feed The feed address
    /// @param feedDecimals The feed's decimal places
    /// @param stalePeriod The maximum age for price data
    /// @return price The price normalized to 18 decimals
    function _getPriceFromFeed(
        address feed,
        uint8 feedDecimals,
        uint256 stalePeriod
    ) private view returns (uint256) {
        (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = AggregatorV3Interface(feed).latestRoundData();
        
        // Check for stale price
        if (block.timestamp - updatedAt > stalePeriod) {
            revert StalePrice(updatedAt, stalePeriod);
        }
        
        // Check for invalid price
        if (price <= 0) {
            revert InvalidPrice();
        }
        
        // Normalize to 18 decimals
        uint256 normalizedPrice;
        if (feedDecimals < TARGET_DECIMALS) {
            normalizedPrice = uint256(price) * 10 ** (TARGET_DECIMALS - feedDecimals);
        } else if (feedDecimals > TARGET_DECIMALS) {
            normalizedPrice = uint256(price) / 10 ** (feedDecimals - TARGET_DECIMALS);
        } else {
            normalizedPrice = uint256(price);
        }
        
        return normalizedPrice;
    }
    
    /// @notice Deactivates a currency pair
    /// @param base The base currency address
    /// @param quote The quote currency address
    function deactivatePair(address base, address quote) external onlyOwner {
        priceFeeds[base][quote].isActive = false;
    }
    
    /// @notice Gets the current configuration for a pair
    /// @param base The base currency address
    /// @param quote The quote currency address
    /// @return config The price feed configuration
    function getPairConfig(address base, address quote) 
        external 
        view 
        returns (PriceFeedConfig memory) 
    {
        return priceFeeds[base][quote];
    }
}
