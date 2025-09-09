# 🌍 Street-Rate Hook

## Overview
A Uniswap v4 Hook that adjusts swap execution based on street exchange rates from an oracle, addressing forex disparities in emerging markets.

## 📁 Project Structure

```
Street-Rate/
├── Smart-Contract/        # All Foundry & smart contract code
│   ├── src/              # Source contracts
│   ├── test/             # Test files
│   ├── script/           # Deployment scripts
│   ├── lib/              # Dependencies (v4-core, v4-periphery)
│   └── foundry.toml      # Foundry configuration
├── Frontend/             # Frontend application (if applicable)
└── docs/                 # Additional documentation
```

## ✨ Features

- 🌍 **Multi-currency support** (NGN, ARS, GHS)
- 💱 **Street rate enforcement** for emerging markets
- 🛡️ **Deviation threshold protection**
- 🎯 **CREATE2 deterministic deployment**
- 🦄 **Full Uniswap V4 integration**
- 🔗 **Chainlink oracle ready**

## 🚀 Quick Start

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Installation
```bash
git clone <repository>
cd Street-Rate/Smart-Contract
forge install
```

### Run Tests
```bash
cd Smart-Contract
forge test                    # Run all tests
forge test -vv               # Verbose output
forge test --summary         # Summary view
```

### Deploy Contracts
```bash
cd Smart-Contract

# Deploy complete system
forge script script/DeployHybridSystem.s.sol --broadcast

# Deploy with CREATE2
forge script script/DeployWithCreate2.s.sol --broadcast

# Deploy with V4 pool
forge script script/DeployPoolWithHook.s.sol --broadcast
```

## 📊 Test Results

| Test Suite | Tests | Status |
|------------|-------|--------|
| StreetRateHookStandalone | 10 | ✅ Pass |
| ChainlinkOracle | 10 | ✅ Pass |
| HybridOracle | 15 | ✅ Pass |
| V4 Pool Integration | 5 | ✅ Pass |
| **Total** | **40** | **100% Pass** |

## 💱 Exchange Rates

| Currency | Official Rate | Street Rate | Deviation |
|----------|--------------|-------------|-----------||
| NGN 🇳🇬 | 800 NGN/USD | 1500 NGN/USD | 46.6% |
| ARS 🇦🇷 | 350 ARS/USD | 1000 ARS/USD | 65.0% |
| GHS 🇬🇭 | 12 GHS/USD | 15 GHS/USD | 19.9% |

## 📝 Documentation

- [Smart Contract README](Smart-Contract/README.md)
- [Chainlink Integration](CHAINLINK_INTEGRATION.md)
- [CREATE2 Deployment](CREATE2_DEPLOYMENT.md)
- [Pool Integration Demo](POOL_INTEGRATION_DEMO.md)
- [Hybrid System](HYBRID_SYSTEM_README.md)

## 🏆 Hackathon Submission

Built for **Uniswap Hook Incubator Hackathon**

### Key Innovations
1. **Real-world problem**: Addresses forex disparities in emerging markets
2. **Multi-currency**: Supports multiple fiat pairs simultaneously
3. **Production ready**: Comprehensive tests and documentation
4. **V4 native**: Fully integrated with Uniswap V4 architecture

## 📦 License

MIT
