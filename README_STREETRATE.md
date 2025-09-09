# StreetRate Hook for Uniswap v4

## Overview

The StreetRate Hook is a Uniswap v4 hook that intercepts swap execution to apply street exchange rates from an oracle, allowing pools to reflect real-world currency exchange rates (particularly useful for emerging market currencies like NGN, GHS, etc.).

## Deliverables

### 1. **StreetRateHookStandalone.sol** - Main Hook Logic
- Location: `src/StreetRateHookStandalone.sol`
- Features:
  - Intercepts swaps and applies street rates from oracle
  - Configurable deviation threshold (default 2%)
  - Reverts if deviation exceeds threshold
  - Emits events for rate checks and swap execution
  - Admin functions for updating oracle and threshold
  - Preview function to check if swap would succeed

### 2. **MockStreetRateOracle.sol** - Demo Oracle
- Location: `src/MockStreetRateOracle.sol`
- Features:
  - Stores official and street rates for currency pairs
  - Allows manual setting of rates for testing
  - Includes helper function for default NGN/USDC rates
  - Easily extendable for multiple currency pairs

### 3. **IStreetRateOracle.sol** - Oracle Interface
- Location: `src/interfaces/IStreetRateOracle.sol`
- Defines the standard interface for rate oracles

### 4. **Comprehensive Test Suite**
- Location: `test/StreetRateHookStandalone.t.sol`
- Tests all required scenarios:
  ✅ Swap at official rate (when official = street rate)
  ✅ Swap at street rate (applied when different)
  ✅ Revert if deviation too high (>2% by default)
  ✅ Configurable threshold works
  ✅ Unsupported pairs revert properly
  ✅ Oracle updates (admin only)
  ✅ Multiple currency pair support (NGN/USDC, GHS/USDC)
  ✅ Preview swap functionality
  ✅ Event emissions
  ✅ Edge cases

## Key Features

### Rate Deviation Control
- **Configurable Threshold**: Default 2% (200 basis points)
- **Automatic Reversion**: Swaps fail if street rate deviates >threshold from official rate
- **Admin Control**: Threshold can be updated by contract owner

### Events
```solidity
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
```

### Error Handling
- `RateDeviationExceeded`: When deviation > threshold
- `UnsupportedPair`: When token pair not in oracle
- `InvalidOracle`: When oracle address is invalid
- `InvalidThreshold`: When threshold value is invalid

## Usage Example

```solidity
// Deploy oracle
MockStreetRateOracle oracle = new MockStreetRateOracle();

// Set rates for NGN/USDC
oracle.setRates(
    ngnAddress,
    usdcAddress,
    625000000000000,   // Official: 1 NGN = 0.000625 USDC
    634375000000000    // Street: 1 NGN = 0.000634375 USDC
);

// Deploy hook with 2% deviation threshold
StreetRateHookStandalone hook = new StreetRateHookStandalone(oracle, 200);

// Execute swap
uint256 amountOut = hook.executeSwap(
    ngnAddress,
    usdcAddress,
    1000e18,  // 1000 NGN
    true      // exact input
);
```

## Running Tests

```bash
# Run all tests
forge test --match-path test/StreetRateHookStandalone.t.sol -vv

# Run with gas reporting
forge test --match-path test/StreetRateHookStandalone.t.sol --gas-report

# Run specific test
forge test --match-test testSwapAtStreetRate -vv
```

## Test Results
All 10 tests pass successfully:
- ✅ testConfigurableThreshold (gas: 53,273)
- ✅ testEdgeCases (gas: 58,482)
- ✅ testEventEmissions (gas: 53,259)
- ✅ testMultipleCurrencyPairs (gas: 132,931)
- ✅ testOracleUpdate (gas: 289,922)
- ✅ testPreviewSwap (gas: 47,793)
- ✅ testRevertOnHighDeviation (gas: 42,701)
- ✅ testSwapAtOfficialRate (gas: 47,073)
- ✅ testSwapAtStreetRate (gas: 50,437)
- ✅ testUnsupportedPair (gas: 21,760)

## Gas Efficiency
The hook is optimized for gas efficiency:
- Simple rate calculation logic
- Minimal storage operations
- Events only for necessary data
- Average swap with rate adjustment: ~50k gas

## Extensibility
The system is designed to be easily extendable:
- Add new currency pairs by calling `setRates()` on oracle
- Integrate with external price feeds by implementing `IStreetRateOracle`
- Adjust deviation thresholds per deployment
- Add additional validation logic in hook

## Production Considerations
For production deployment:
1. Replace `MockStreetRateOracle` with production oracle (Chainlink, API3, etc.)
2. Implement proper access control for oracle updates
3. Consider time-weighted average prices (TWAP) for rate stability
4. Add circuit breakers for extreme market conditions
5. Implement multi-sig for admin functions

## Architecture Notes
This is a standalone implementation optimized for:
- **Demo-ability**: Easy to understand and test
- **Gas efficiency**: Minimal overhead on swaps
- **Flexibility**: Easy to extend for multiple currencies
- **Security**: Clear reversion conditions and admin controls

The hook can be integrated with Uniswap v4's full hook infrastructure when the BaseHook dependencies are properly configured.
