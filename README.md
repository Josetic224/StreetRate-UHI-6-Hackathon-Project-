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

# Deploy complete system to Lisk Sepolia
./deploy.sh

# Or manually with Foundry
forge script script/DeployWithCreate2.s.sol:DeployWithCreate2 \
    --rpc-url https://rpc.sepolia-api.lisk.com \
    --chain-id 4202 \
    --broadcast
```

## 🔗 Deployed Contracts (Lisk Sepolia)

### 💰 Tokens
| Token | Address |
|-------|----------|
| NGN | `0xca51E513ED59eC15592C9E9672b7F31C9bD20c6a` |
| ARS | `0xbebcA094FaF7cED5239c63bE318E1d5C0DefF8Ea` |
| GHS | `0xD0C1F10D3632C0f4A5021209421eA476797cFd77` |
| USDC | `0x698da064496CE35DC5FB63E06CF1B19Ef4076e71` |

### 🏢 Infrastructure
| Contract | Address |
|----------|----------|
| Oracle | `0x736b667295d2F18489Af1548082c86fd4C3750E5` |
| Hook | `0x09ACf156789F81E854c4aE594f16Ec1E241d97aD` |
| HookDeployer | `0x655204fc0Be886ef5f96Ade62F76b1B240a7d953` |

**Network**: Lisk Sepolia (Chain ID: 4202)  
**Explorer**: https://sepolia-blockscout.lisk.com

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
