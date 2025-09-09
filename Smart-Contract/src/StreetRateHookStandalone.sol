// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IStreetRateOracle.sol";

/// @title StreetRateHookStandalone
/// @notice Simplified Uniswap v4 Hook that adjusts swap execution based on street rate oracle
/// @dev This is a standalone implementation for demo purposes
contract StreetRateHookStandalone {
    /// @notice Custom errors
    error RateDeviationExceeded(uint256 officialRate, uint256 streetRate, uint256 deviation, uint256 maxDeviation);
    error UnsupportedPair(address token0, address token1);
    error InvalidOracle();
    error InvalidThreshold();

    /// @notice Events
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
    
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event DeviationThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    /// @notice The street rate oracle
    IStreetRateOracle public oracle;
    
    /// @notice Maximum allowed deviation between official and street rate (in basis points)
    /// Default: 200 = 2%
    uint256 public deviationThreshold;
    
    /// @notice Constant for basis points calculation
    uint256 private constant BASIS_POINTS = 10000;
    
    /// @notice Owner of the hook (for admin functions)
    address public immutable owner;

    constructor(IStreetRateOracle _oracle, uint256 _deviationThreshold) {
        if (address(_oracle) == address(0)) revert InvalidOracle();
        if (_deviationThreshold == 0 || _deviationThreshold > BASIS_POINTS) revert InvalidThreshold();
        
        oracle = _oracle;
        deviationThreshold = _deviationThreshold;
        owner = msg.sender;
    }

    /// @notice Executes a swap with street rate adjustment
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    /// @param amountIn The input amount
    /// @param isExactInput Whether this is an exact input swap
    /// @return amountOut The output amount after street rate adjustment
    function executeSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        bool isExactInput
    ) external returns (uint256 amountOut) {
        // Check if pair is supported by oracle
        if (!oracle.isPairSupported(tokenIn, tokenOut)) {
            revert UnsupportedPair(tokenIn, tokenOut);
        }
        
        // Get rates from oracle
        uint256 officialRate = oracle.getOfficialRate(tokenIn, tokenOut);
        uint256 streetRate = oracle.getStreetRate(tokenIn, tokenOut);
        
        // Calculate deviation
        uint256 deviation = _calculateDeviation(officialRate, streetRate);
        
        // Check if deviation exceeds threshold
        if (deviation > deviationThreshold) {
            revert RateDeviationExceeded(officialRate, streetRate, deviation, deviationThreshold);
        }
        
        // Calculate output based on street rate
        if (isExactInput) {
            amountOut = (amountIn * streetRate) / 1e18;
        } else {
            // For exact output, calculate required input
            amountOut = (amountIn * 1e18) / streetRate;
        }
        
        emit RateChecked(tokenIn, tokenOut, officialRate, streetRate, streetRate);
        emit SwapExecuted(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
        
        return amountOut;
    }

    /// @notice Calculates the deviation between official and street rates
    /// @param officialRate The official exchange rate
    /// @param streetRate The street exchange rate
    /// @return deviation The deviation in basis points
    function _calculateDeviation(uint256 officialRate, uint256 streetRate) private pure returns (uint256) {
        if (officialRate == 0) return BASIS_POINTS; // Max deviation if official rate is 0
        
        uint256 diff = officialRate > streetRate 
            ? officialRate - streetRate 
            : streetRate - officialRate;
            
        return (diff * BASIS_POINTS) / officialRate;
    }

    /// @notice Updates the oracle address (admin only)
    /// @param newOracle The new oracle address
    function updateOracle(IStreetRateOracle newOracle) external {
        require(msg.sender == owner, "Only owner");
        if (address(newOracle) == address(0)) revert InvalidOracle();
        
        address oldOracle = address(oracle);
        oracle = newOracle;
        
        emit OracleUpdated(oldOracle, address(newOracle));
    }

    /// @notice Updates the deviation threshold (admin only)
    /// @param newThreshold The new threshold in basis points
    function updateDeviationThreshold(uint256 newThreshold) external {
        require(msg.sender == owner, "Only owner");
        if (newThreshold == 0 || newThreshold > BASIS_POINTS) revert InvalidThreshold();
        
        uint256 oldThreshold = deviationThreshold;
        deviationThreshold = newThreshold;
        
        emit DeviationThresholdUpdated(oldThreshold, newThreshold);
    }
    
    /// @notice View function to check if a swap would succeed
    /// @param tokenIn The input token
    /// @param tokenOut The output token
    /// @param amountIn The input amount
    /// @return wouldSucceed Whether the swap would succeed
    /// @return expectedOut The expected output amount
    /// @return appliedRate The rate that would be applied
    function previewSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (
        bool wouldSucceed,
        uint256 expectedOut,
        uint256 appliedRate
    ) {
        if (!oracle.isPairSupported(tokenIn, tokenOut)) {
            return (false, 0, 0);
        }
        
        uint256 officialRate = oracle.getOfficialRate(tokenIn, tokenOut);
        uint256 streetRate = oracle.getStreetRate(tokenIn, tokenOut);
        
        uint256 deviation = _calculateDeviation(officialRate, streetRate);
        
        if (deviation > deviationThreshold) {
            return (false, 0, 0);
        }
        
        expectedOut = (amountIn * streetRate) / 1e18;
        return (true, expectedOut, streetRate);
    }
}
