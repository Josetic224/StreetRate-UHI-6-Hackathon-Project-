# 📦 Smart Contract Directory

This directory contains all Foundry-related smart contract code for the Street Rate Hook project.

## 📁 Structure

```
Smart-Contract/
├── src/                    # Source contracts
│   ├── StreetRateHookStandalone.sol
│   ├── StreetRateHookV4Simple.sol
│   ├── HookDeployer.sol
│   ├── MockStreetRateOracle.sol
│   ├── ChainlinkStreetRateOracle.sol
│   ├── HybridRateOracle.sol
│   ├── tokens/            # Mock fiat tokens
│   ├── interfaces/        # Contract interfaces
│   └── libraries/         # Helper libraries
├── test/                  # Test files
│   ├── StreetRateHookStandalone.t.sol
│   ├── ChainlinkStreetRateOracle.t.sol
│   ├── HybridRateOracle.t.sol
│   └── SwapWithHook.t.sol
├── script/                # Deployment scripts
│   ├── DeployStreetRateHook.s.sol
│   ├── DeployChainlinkOracle.s.sol
│   ├── DeployHybridSystem.s.sol
│   ├── DeployWithCreate2.s.sol
│   └── DeployPoolWithHook.s.sol
├── lib/                   # Dependencies
│   ├── v4-core/          # Uniswap V4 core
│   ├── v4-periphery/     # Uniswap V4 periphery
│   └── forge-std/        # Foundry standard library
├── out/                   # Compiled artifacts
├── cache/                 # Build cache
└── foundry.toml          # Foundry configuration
```

## 🚀 Quick Start

### Install Dependencies
```bash
cd Smart-Contract
forge install
```

### Run Tests
```bash
# Run all tests
forge test

# Run with verbosity
forge test -vv

# Run specific test file
forge test --match-path test/HybridRateOracle.t.sol
```

### Deploy Contracts
```bash
# Deploy complete system
forge script script/DeployHybridSystem.s.sol --broadcast

# Deploy with CREATE2
forge script script/DeployWithCreate2.s.sol --broadcast

# Deploy with V4 pool
forge script script/DeployPoolWithHook.s.sol --broadcast
```

## 📊 Test Coverage

- **40 Total Tests**
- **100% Passing**
- **4 Test Suites**:
  - StreetRateHookStandalone: 10 tests
  - ChainlinkOracle: 10 tests
  - HybridOracle: 15 tests
  - V4 Pool Integration: 5 tests

## 🔧 Configuration

The `foundry.toml` file contains:
- Solidity version: 0.8.26
- EVM version: Cancun
- Optimizer: 200 runs
- Remappings for v4-core and v4-periphery

## 📝 Key Contracts

1. **StreetRateHookV4Simple.sol** - Main Uniswap V4 hook
2. **HybridRateOracle.sol** - Multi-currency oracle
3. **HookDeployer.sol** - CREATE2 deployment
4. **FiatTokens.sol** - Mock NGN, ARS, GHS tokens

## 🎯 Features

- ✅ Multi-currency support (NGN, ARS, GHS)
- ✅ Street rate enforcement
- ✅ Deviation threshold protection
- ✅ CREATE2 deterministic deployment
- ✅ Uniswap V4 integration
- ✅ Chainlink oracle ready

---

Built for Uniswap Hook Incubator Hackathon 🦄
