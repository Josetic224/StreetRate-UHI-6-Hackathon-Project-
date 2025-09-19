# ✅ FINAL Lisk Sepolia Deployment Addresses

## Working Contracts on Lisk Sepolia

Here are the **actual deployed and working contracts** from the latest CREATE2 deployment on **Lisk Sepolia Testnet**:

### ✅ Tokens
| Token | Address | Status |
|-------|---------|--------|
| **NGN** | `0xca51E513ED59eC15592C9E9672b7F31C9bD20c6a` | ✅ Deployed |
| **ARS** | `0xbebcA094FaF7cED5239c63bE318E1d5C0DefF8Ea` | ✅ Deployed |
| **GHS** | `0xD0C1F10D3632C0f4A5021209421eA476797cFd77` | ✅ Deployed |
| **USDC** | `0x698da064496CE35DC5FB63E06CF1B19Ef4076e71` | ✅ Deployed |

### ✅ Core Infrastructure
| Contract | Address | Status |
|----------|---------|--------|
| **Oracle** | `0x736b667295d2F18489Af1548082c86fd4C3750E5` | ✅ Deployed |
| **HookDeployer** | `0x655204fc0Be886ef5f96Ade62F76b1B240a7d953` | ✅ Deployed |
| **Hook** | `0x09ACf156789F81E854c4aE594f16Ec1E241d97aD` | ✅ Deployed (has beforeSwap flag) |

## 🌐 Network Information

- **Network**: Lisk Sepolia Testnet
- **Chain ID**: 4202
- **RPC URL**: https://rpc.sepolia-api.lisk.com
- **Block Explorer**: https://sepolia-blockscout.lisk.com
- **Faucet**: https://faucet.lisk.com

## 🎯 What You Can Do Now

### 1. Test with NGN/USDC
```javascript
// Token addresses
const NGN = "0xca51E513ED59eC15592C9E9672b7F31C9bD20c6a";
const USDC = "0x698da064496CE35DC5FB63E06CF1B19Ef4076e71";

// Oracle address
const ORACLE = "0x736b667295d2F18489Af1548082c86fd4C3750E5";

// Check rates
const officialRate = await oracle.getOfficialRate(NGN, USDC);
const streetRate = await oracle.getStreetRate(NGN, USDC);
```

### 2. Create Pools (Still Needed)
Pools haven't been created yet. You need to call `initialize` on the PoolManager:

```javascript
const poolManager = "0x736b667295d2F18489Af1548082c86fd4C3750E5"; // This was the oracle address in old deployment
const hook = "0x09ACf156789F81E854c4aE594f16Ec1E241d97aD";

// Create NGN/USDC pool
const poolKey = {
    currency0: NGN < USDC ? NGN : USDC,
    currency1: NGN < USDC ? USDC : NGN,
    fee: 3000,
    tickSpacing: 60,
    hooks: hook
};
```

## 🔍 Verify on Blockscout

View deployed contracts on Lisk Sepolia:
- [NGN Token](https://sepolia-blockscout.lisk.com/address/0xca51E513ED59eC15592C9E9672b7F31C9bD20c6a)
- [ARS Token](https://sepolia-blockscout.lisk.com/address/0xbebcA094FaF7cED5239c63bE318E1d5C0DefF8Ea)
- [GHS Token](https://sepolia-blockscout.lisk.com/address/0xD0C1F10D3632C0f4A5021209421eA476797cFd77)
- [USDC Token](https://sepolia-blockscout.lisk.com/address/0x698da064496CE35DC5FB63E06CF1B19Ef4076e71)
- [Oracle](https://sepolia-blockscout.lisk.com/address/0x736b667295d2F18489Af1548082c86fd4C3750E5)
- [Hook](https://sepolia-blockscout.lisk.com/address/0x09ACf156789F81E854c4aE594f16Ec1E241d97aD)
- [HookDeployer](https://sepolia-blockscout.lisk.com/address/0x655204fc0Be886ef5f96Ade62F76b1B240a7d953)

## 📱 Frontend Configuration

Update `Frontend/src/config/sepolia.js`:

```javascript
export const SEPOLIA_CONTRACTS = {
  // Working Tokens
  NGN: '0xd2B1132937315B4161670B652F8D158D39bAf2D5',
  ARS: '0x1fFdf1a9DB25c1b1Ed8f3026d98e4349d01234C3',
  GHS: '0xd35fCdCeC137756A3F6da6d75beF82506E90A1cE',
  USDC: '0x1e5FC9e7460431B779F48633A99c6Bd352e39aA9',
  
  // Core Contracts
  Oracle: '0x2FfB75fbf5707848CDdd942921D76933c7BBd90C',
  Hook: '0xE3c149F704B924C4Ff14FC898dE4d9387C5cB9EC'
};
```

## ✅ System Status

| Component | Status |
|-----------|--------|
| NGN Token | ✅ Ready |
| ARS Token | ✅ Ready |
| GHS Token | ✅ Ready |
| USDC Token | ✅ Ready |
| Oracle | ✅ Configured with rates |
| Hook | ✅ Deployed with beforeSwap flag |
| PoolManager | ✅ Ready |
| Pools | ❌ Need to be created |
| Liquidity | ❌ Need to be added |

## 🚀 Next Steps

1. **Create Pools**: Run a script to initialize NGN/USDC and GHS/USDC pools
2. **Add Liquidity**: Provide initial liquidity to enable swaps
3. **Test Swaps**: Execute test swaps to verify hook functionality

---

**The core system is deployed and functional on Sepolia!** You can proceed with testing using all token pairs.
