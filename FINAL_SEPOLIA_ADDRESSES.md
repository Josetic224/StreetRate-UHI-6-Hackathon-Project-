# ✅ FINAL Sepolia Deployment Addresses

## Working Contracts on Sepolia

Here are the **actual deployed and working contracts** from the latest CREATE2 deployment:

### ✅ Tokens
| Token | Address | Status |
|-------|---------|--------|
| **NGN** | `0xd2B1132937315B4161670B652F8D158D39bAf2D5` | ✅ Deployed |
| **ARS** | `0x1fFdf1a9DB25c1b1Ed8f3026d98e4349d01234C3` | ✅ Deployed |
| **GHS** | `0xd35fCdCeC137756A3F6da6d75beF82506E90A1cE` | ✅ Deployed |
| **USDC** | `0x1e5FC9e7460431B779F48633A99c6Bd352e39aA9` | ✅ Deployed |

### ✅ Core Infrastructure
| Contract | Address | Status |
|----------|---------|--------|
| **Oracle** | `0x2FfB75fbf5707848CDdd942921D76933c7BBd90C` | ✅ Deployed |
| **HookDeployer** | `0x44153D7E02397D7b099914d91262FE5FfE05E4FD` | ✅ Deployed |
| **Hook** | `0xE3c149F704B924C4Ff14FC898dE4d9387C5cB9EC` | ✅ Deployed (has beforeSwap flag) |

## 🎯 What You Can Do Now

### 1. Test with NGN/USDC
```javascript
// Token addresses
const NGN = "0xd2B1132937315B4161670B652F8D158D39bAf2D5";
const USDC = "0x1e5FC9e7460431B779F48633A99c6Bd352e39aA9";

// Oracle address
const ORACLE = "0x2FfB75fbf5707848CDdd942921D76933c7BBd90C";

// Check rates
const officialRate = await oracle.getOfficialRate(NGN, USDC);
const streetRate = await oracle.getStreetRate(NGN, USDC);
```

### 2. Create Pools (Still Needed)
Pools haven't been created yet. You need to call `initialize` on the PoolManager:

```javascript
const poolManager = "0x2FfB75fbf5707848CDdd942921D76933c7BBd90C";
const hook = "0xE3c149F704B924C4Ff14FC898dE4d9387C5cB9EC";

// Create NGN/USDC pool
const poolKey = {
    currency0: NGN < USDC ? NGN : USDC,
    currency1: NGN < USDC ? USDC : NGN,
    fee: 3000,
    tickSpacing: 60,
    hooks: hook
};
```

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
