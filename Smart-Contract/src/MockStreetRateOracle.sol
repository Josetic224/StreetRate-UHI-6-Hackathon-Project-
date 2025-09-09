// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IStreetRateOracle.sol";

/// @title MockStreetRateOracle
/// @notice Mock oracle for testing street rate functionality
contract MockStreetRateOracle is IStreetRateOracle {
    struct RatePair {
        uint256 officialRate;
        uint256 streetRate;
        bool isSupported;
    }
    
    // Mapping from base => quote => rates
    mapping(address => mapping(address => RatePair)) public rates;
    
    // Events
    event RatesSet(address indexed base, address indexed quote, uint256 officialRate, uint256 streetRate);
    
    /// @notice Sets rates for a currency pair
    /// @param base The base currency address
    /// @param quote The quote currency address
    /// @param officialRate The official exchange rate (18 decimals)
    /// @param streetRate The street exchange rate (18 decimals)
    function setRates(
        address base,
        address quote,
        uint256 officialRate,
        uint256 streetRate
    ) external {
        rates[base][quote] = RatePair({
            officialRate: officialRate,
            streetRate: streetRate,
            isSupported: true
        });
        
        emit RatesSet(base, quote, officialRate, streetRate);
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
    
    /// @notice Sets a default NGN/USDC rate for testing
    /// @param ngn The NGN token address
    /// @param usdc The USDC token address
    function setDefaultNGNUSDCRates(address ngn, address usdc) external {
        // Example: 1 USDC = 1600 NGN official, 1650 NGN street
        // So 1 NGN = 0.000625 USDC official, 0.000606 USDC street
        // With 18 decimals: 625000000000000 and 606060606060606
        uint256 officialRate = 625000000000000; // 1 NGN = 0.000625 USDC
        uint256 streetRate = 606060606060606;   // 1 NGN = 0.000606 USDC (street rate)
        
        rates[ngn][usdc] = RatePair({
            officialRate: officialRate,
            streetRate: streetRate,
            isSupported: true
        });
        
        emit RatesSet(ngn, usdc, officialRate, streetRate);
    }
}
