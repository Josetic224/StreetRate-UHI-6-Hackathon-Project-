// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IStreetRateOracle.sol";

/// @title HybridRateOracle
/// @notice Multi-currency oracle that stores official and street rates for multiple fiat pairs
/// @dev Designed for hackathon demo showcasing FX disparities across emerging markets
contract HybridRateOracle is IStreetRateOracle {
    struct RatePair {
        uint256 officialRate;  // Official exchange rate (18 decimals)
        uint256 streetRate;    // Street/parallel market rate (18 decimals)
        bool isSupported;      // Whether this pair is configured
        string currencyCode;   // ISO code for display (e.g., "NGN", "ARS")
        string countryFlag;    // Emoji flag for UI (e.g., "🇳🇬", "🇦🇷")
    }
    
    /// @notice Mapping from base => quote => rates
    mapping(address => mapping(address => RatePair)) public rates;
    
    /// @notice List of all configured currency addresses for enumeration
    address[] public supportedCurrencies;
    mapping(address => bool) public isCurrencyAdded;
    
    /// @notice Admin/owner of the oracle
    address public immutable owner;
    
    /// @notice Events
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
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /// @notice Configure rates for a new currency pair
    /// @param base The base currency (fiat token address)
    /// @param quote The quote currency (USDC address)
    /// @param officialRate The official exchange rate (e.g., 1 USDC = 800 NGN)
    /// @param streetRate The street/parallel rate (e.g., 1 USDC = 1500 NGN)
    /// @param currencyCode ISO code for the currency
    /// @param countryFlag Emoji flag for UI display
    function configureRates(
        address base,
        address quote,
        uint256 officialRate,
        uint256 streetRate,
        string memory currencyCode,
        string memory countryFlag
    ) external onlyOwner {
        require(base != address(0) && quote != address(0), "Invalid addresses");
        require(officialRate > 0 && streetRate > 0, "Invalid rates");
        
        // Track if this is a new currency
        if (!isCurrencyAdded[base]) {
            supportedCurrencies.push(base);
            isCurrencyAdded[base] = true;
        }
        
        rates[base][quote] = RatePair({
            officialRate: officialRate,
            streetRate: streetRate,
            isSupported: true,
            currencyCode: currencyCode,
            countryFlag: countryFlag
        });
        
        emit RatesConfigured(base, quote, officialRate, streetRate, currencyCode, countryFlag);
    }
    
    /// @notice Update rates for an existing pair
    /// @param base The base currency address
    /// @param quote The quote currency address
    /// @param newOfficialRate New official rate
    /// @param newStreetRate New street rate
    function updateRates(
        address base,
        address quote,
        uint256 newOfficialRate,
        uint256 newStreetRate
    ) external onlyOwner {
        require(rates[base][quote].isSupported, "Pair not configured");
        require(newOfficialRate > 0 && newStreetRate > 0, "Invalid rates");
        
        uint256 oldOfficial = rates[base][quote].officialRate;
        uint256 oldStreet = rates[base][quote].streetRate;
        
        rates[base][quote].officialRate = newOfficialRate;
        rates[base][quote].streetRate = newStreetRate;
        
        emit RatesUpdated(base, quote, oldOfficial, newOfficialRate, oldStreet, newStreetRate);
    }
    
    /// @inheritdoc IStreetRateOracle
    function getOfficialRate(address base, address quote) external view override returns (uint256) {
        require(rates[base][quote].isSupported, "Pair not supported");
        return rates[base][quote].officialRate;
    }
    
    /// @inheritdoc IStreetRateOracle
    function getStreetRate(address base, address quote) external view override returns (uint256) {
        require(rates[base][quote].isSupported, "Pair not supported");
        return rates[base][quote].streetRate;
    }
    
    /// @inheritdoc IStreetRateOracle
    function isPairSupported(address base, address quote) external view override returns (bool) {
        return rates[base][quote].isSupported;
    }
    
    /// @notice Get full rate information for a pair
    /// @param base The base currency address
    /// @param quote The quote currency address
    /// @return ratePair The complete rate information
    function getRatePair(address base, address quote) external view returns (RatePair memory) {
        require(rates[base][quote].isSupported, "Pair not supported");
        return rates[base][quote];
    }
    
    /// @notice Get all supported currency addresses
    /// @return currencies Array of supported currency addresses
    function getSupportedCurrencies() external view returns (address[] memory) {
        return supportedCurrencies;
    }
    
    /// @notice Get the count of supported currencies
    /// @return count Number of supported currencies
    function getCurrencyCount() external view returns (uint256) {
        return supportedCurrencies.length;
    }
    
    /// @notice Calculate the percentage deviation between official and street rates
    /// @param base The base currency address
    /// @param quote The quote currency address
    /// @return deviation The deviation in basis points (100 = 1%)
    function getDeviation(address base, address quote) external view returns (uint256) {
        require(rates[base][quote].isSupported, "Pair not supported");
        
        uint256 official = rates[base][quote].officialRate;
        uint256 street = rates[base][quote].streetRate;
        
        if (official == 0) return 10000; // 100% deviation if official is 0
        
        uint256 diff = official > street ? official - street : street - official;
        return (diff * 10000) / official;
    }
    
    /// @notice Batch configure multiple currency pairs
    /// @param bases Array of base currency addresses
    /// @param quote The quote currency (USDC) address
    /// @param officialRates Array of official rates
    /// @param streetRates Array of street rates
    /// @param codes Array of currency codes
    /// @param flags Array of country flags
    function batchConfigureRates(
        address[] calldata bases,
        address quote,
        uint256[] calldata officialRates,
        uint256[] calldata streetRates,
        string[] calldata codes,
        string[] calldata flags
    ) external onlyOwner {
        require(
            bases.length == officialRates.length &&
            bases.length == streetRates.length &&
            bases.length == codes.length &&
            bases.length == flags.length,
            "Array length mismatch"
        );
        
        for (uint256 i = 0; i < bases.length; i++) {
            if (!isCurrencyAdded[bases[i]]) {
                supportedCurrencies.push(bases[i]);
                isCurrencyAdded[bases[i]] = true;
            }
            
            rates[bases[i]][quote] = RatePair({
                officialRate: officialRates[i],
                streetRate: streetRates[i],
                isSupported: true,
                currencyCode: codes[i],
                countryFlag: flags[i]
            });
            
            emit RatesConfigured(
                bases[i],
                quote,
                officialRates[i],
                streetRates[i],
                codes[i],
                flags[i]
            );
        }
    }
    
    /// @notice Initialize with default rates for demo
    /// @param ngn Nigerian Naira token address
    /// @param ars Argentine Peso token address
    /// @param ghs Ghanaian Cedi token address
    /// @param usdc USDC token address
    function initializeDefaultRates(
        address ngn,
        address ars,
        address ghs,
        address usdc
    ) external onlyOwner {
        // NGN/USDC rates
        // Official: 1 USDC = 800 NGN, so 1 NGN = 0.00125 USDC
        // Street: 1 USDC = 1500 NGN, so 1 NGN = 0.000667 USDC
        if (!isCurrencyAdded[ngn]) {
            supportedCurrencies.push(ngn);
            isCurrencyAdded[ngn] = true;
        }
        rates[ngn][usdc] = RatePair({
            officialRate: 1250000000000000,   // 0.00125 USDC per NGN
            streetRate: 667000000000000,      // 0.000667 USDC per NGN
            isSupported: true,
            currencyCode: "NGN",
            countryFlag: unicode"🇳🇬"
        });
        
        // ARS/USDC rates
        // Official: 1 USDC = 350 ARS, so 1 ARS = 0.00286 USDC
        // Street: 1 USDC = 1000 ARS, so 1 ARS = 0.001 USDC
        if (!isCurrencyAdded[ars]) {
            supportedCurrencies.push(ars);
            isCurrencyAdded[ars] = true;
        }
        rates[ars][usdc] = RatePair({
            officialRate: 2860000000000000,   // 0.00286 USDC per ARS
            streetRate: 1000000000000000,     // 0.001 USDC per ARS
            isSupported: true,
            currencyCode: "ARS",
            countryFlag: unicode"🇦🇷"
        });
        
        // GHS/USDC rates
        // Official: 1 USDC = 12 GHS, so 1 GHS = 0.0833 USDC
        // Street: 1 USDC = 15 GHS, so 1 GHS = 0.0667 USDC
        if (!isCurrencyAdded[ghs]) {
            supportedCurrencies.push(ghs);
            isCurrencyAdded[ghs] = true;
        }
        rates[ghs][usdc] = RatePair({
            officialRate: 83300000000000000,  // 0.0833 USDC per GHS
            streetRate: 66700000000000000,    // 0.0667 USDC per GHS
            isSupported: true,
            currencyCode: "GHS",
            countryFlag: unicode"🇬🇭"
        });
        
        emit RatesConfigured(ngn, usdc, rates[ngn][usdc].officialRate, rates[ngn][usdc].streetRate, "NGN", unicode"🇳🇬");
        emit RatesConfigured(ars, usdc, rates[ars][usdc].officialRate, rates[ars][usdc].streetRate, "ARS", unicode"🇦🇷");
        emit RatesConfigured(ghs, usdc, rates[ghs][usdc].officialRate, rates[ghs][usdc].streetRate, "GHS", unicode"🇬🇭");
    }
}
