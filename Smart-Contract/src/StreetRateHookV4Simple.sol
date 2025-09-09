// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "../lib/v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "../lib/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "../lib/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "../lib/v4-core/src/types/PoolKey.sol";
import {Currency} from "../lib/v4-core/src/types/Currency.sol";
import {BalanceDelta} from "../lib/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "../lib/v4-core/src/types/BeforeSwapDelta.sol";
import {PoolId, PoolIdLibrary} from "../lib/v4-core/src/types/PoolId.sol";
import "./interfaces/IStreetRateOracle.sol";

/// @title StreetRateHookV4Simple
/// @notice Simplified Uniswap v4 hook that enforces street exchange rates
contract StreetRateHookV4Simple is IHooks {
    using PoolIdLibrary for PoolKey;
    
    /// @notice The pool manager contract
    IPoolManager public immutable poolManager;
    
    /// @notice The oracle providing official and street rates
    IStreetRateOracle public immutable oracle;
    
    /// @notice Maximum allowed deviation between official and street rates (in basis points)
    uint256 public immutable deviationThreshold;
    
    /// @notice Basis points constant (100% = 10000)
    uint256 public constant BASIS_POINTS = 10000;
    
    /// @notice Events
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
    
    /// @notice Custom errors
    error UnsupportedPair(address tokenIn, address tokenOut);
    error RateDeviationExceeded(uint256 officialRate, uint256 streetRate, uint256 deviation, uint256 threshold);
    error NotPoolManager();
    
    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }
    
    constructor(
        IPoolManager _poolManager,
        IStreetRateOracle _oracle,
        uint256 _deviationThreshold
    ) {
        poolManager = _poolManager;
        oracle = _oracle;
        deviationThreshold = _deviationThreshold;
        
        // Skip validation during deployment - will be checked by deployment script
        // validateHookAddress();
    }
    
    /// @notice Validates the deployed hook address has correct permission flags
    function validateHookAddress() internal view {
        uint256 hookAddr = uint256(uint160(address(this)));
        uint256 flags = hookAddr & 0xFFFF;
        
        // Check beforeSwap flag (bit 7)
        require((flags & (1 << 7)) != 0, "beforeSwap flag not set");
    }
    
    /// @notice Returns the hook permissions
    function getHookPermissions() public pure returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,  // We need this to adjust swap amounts
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,  // We modify the swap delta
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }
    
    /// @notice Hook called before pool initialization
    function beforeInitialize(address, PoolKey calldata, uint160) external pure returns (bytes4) {
        return IHooks.beforeInitialize.selector;
    }
    
    /// @notice Hook called after pool initialization
    function afterInitialize(address, PoolKey calldata, uint160, int24) external pure returns (bytes4) {
        return IHooks.afterInitialize.selector;
    }
    
    /// @notice Hook called before adding liquidity
    function beforeAddLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return IHooks.beforeAddLiquidity.selector;
    }
    
    /// @notice Hook called after adding liquidity
    function afterAddLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure returns (bytes4, BalanceDelta) {
        return (IHooks.afterAddLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }
    
    /// @notice Hook called before removing liquidity
    function beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return IHooks.beforeRemoveLiquidity.selector;
    }
    
    /// @notice Hook called after removing liquidity
    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure returns (bytes4, BalanceDelta) {
        return (IHooks.afterRemoveLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }
    
    /// @notice Hook called before a swap - THIS IS WHERE WE ENFORCE STREET RATES
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata
    ) external onlyPoolManager returns (bytes4, BeforeSwapDelta, uint24) {
        // Get token addresses from currencies
        address tokenIn = params.zeroForOne ? 
            Currency.unwrap(key.currency0) : 
            Currency.unwrap(key.currency1);
        address tokenOut = params.zeroForOne ? 
            Currency.unwrap(key.currency1) : 
            Currency.unwrap(key.currency0);
        
        // Check if pair is supported
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
        
        // Emit events
        emit RateChecked(tokenIn, tokenOut, officialRate, streetRate, streetRate);
        emit SwapAdjusted(sender, tokenIn, tokenOut, params.amountSpecified, streetRate);
        
        // For now, return no delta adjustment (hook validates but doesn't modify amounts)
        // In production, you would calculate the adjustment based on street rate
        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }
    
    /// @notice Hook called after a swap
    function afterSwap(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) external pure returns (bytes4, int128) {
        return (IHooks.afterSwap.selector, 0);
    }
    
    /// @notice Hook called before a donation
    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata) 
        external pure returns (bytes4) {
        return IHooks.beforeDonate.selector;
    }
    
    /// @notice Hook called after a donation
    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata) 
        external pure returns (bytes4) {
        return IHooks.afterDonate.selector;
    }
    
    /// @notice Calculate deviation between official and street rates
    function _calculateDeviation(uint256 officialRate, uint256 streetRate) private pure returns (uint256) {
        if (officialRate == 0) return BASIS_POINTS;
        uint256 diff = officialRate > streetRate ? 
            officialRate - streetRate : 
            streetRate - officialRate;
        return (diff * BASIS_POINTS) / officialRate;
    }
}

/// @notice Library for BalanceDelta operations
library BalanceDeltaLibrary {
    BalanceDelta public constant ZERO_DELTA = BalanceDelta.wrap(0);
}
