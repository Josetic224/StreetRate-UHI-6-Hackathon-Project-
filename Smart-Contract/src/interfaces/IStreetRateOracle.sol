// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IStreetRateOracle
/// @notice Interface for street rate oracle that provides both official and street rates
interface IStreetRateOracle {
    /// @notice Returns the official exchange rate
    /// @param base The base currency (e.g., NGN)
    /// @param quote The quote currency (e.g., USDC)
    /// @return rate The official exchange rate with 18 decimals precision
    function getOfficialRate(address base, address quote) external view returns (uint256 rate);
    
    /// @notice Returns the street exchange rate
    /// @param base The base currency (e.g., NGN)
    /// @param quote The quote currency (e.g., USDC)
    /// @return rate The street exchange rate with 18 decimals precision
    function getStreetRate(address base, address quote) external view returns (uint256 rate);
    
    /// @notice Checks if a currency pair is supported
    /// @param base The base currency
    /// @param quote The quote currency
    /// @return supported True if the pair is supported
    function isPairSupported(address base, address quote) external view returns (bool supported);
}
