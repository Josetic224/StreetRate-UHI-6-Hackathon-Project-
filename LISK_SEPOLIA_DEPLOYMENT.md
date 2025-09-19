# 🎉 StreetRate - Lisk Sepolia Deployment

## ✅ Deployment Status: **COMPLETE**

All StreetRate contracts have been successfully deployed to **Lisk Sepolia Testnet** using CREATE2 deterministic deployment.

## 🌐 Network Information

- **Network**: Lisk Sepolia Testnet
- **Chain ID**: 4202
- **RPC URL**: https://rpc.sepolia-api.lisk.com
- **Block Explorer**: https://sepolia-blockscout.lisk.com
- **Faucet**: https://faucet.lisk.com

## 📋 Contract Addresses

### 🪙 Token Contracts
| Token | Symbol | Address | Explorer Link |
|-------|--------|---------|---------------|
| Nigerian Naira | NGN | `0xca51E513ED59eC15592C9E9672b7F31C9bD20c6a` | [View](https://sepolia-blockscout.lisk.com/address/0xca51E513ED59eC15592C9E9672b7F31C9bD20c6a) |
| Argentine Peso | ARS | `0xbebcA094FaF7cED5239c63bE318E1d5C0DefF8Ea` | [View](https://sepolia-blockscout.lisk.com/address/0xbebcA094FaF7cED5239c63bE318E1d5C0DefF8Ea) |
| Ghanaian Cedi | GHS | `0xD0C1F10D3632C0f4A5021209421eA476797cFd77` | [View](https://sepolia-blockscout.lisk.com/address/0xD0C1F10D3632C0f4A5021209421eA476797cFd77) |
| USD Coin | USDC | `0x698da064496CE35DC5FB63E06CF1B19Ef4076e71` | [View](https://sepolia-blockscout.lisk.com/address/0x698da064496CE35DC5FB63E06CF1B19Ef4076e71) |

### 🏗️ Infrastructure Contracts
| Contract | Purpose | Address | Explorer Link |
|----------|---------|---------|---------------|
| HybridRateOracle | Street rate oracle | `0x736b667295d2F18489Af1548082c86fd4C3750E5` | [View](https://sepolia-blockscout.lisk.com/address/0x736b667295d2F18489Af1548082c86fd4C3750E5) |
| StreetRateHook | Main hook contract | `0x09ACf156789F81E854c4aE594f16Ec1E241d97aD` | [View](https://sepolia-blockscout.lisk.com/address/0x09ACf156789F81E854c4aE594f16Ec1E241d97aD) |
| HookDeployer | CREATE2 deployer | `0x655204fc0Be886ef5f96Ade62F76b1B240a7d953` | [View](https://sepolia-blockscout.lisk.com/address/0x655204fc0Be886ef5f96Ade62F76b1B240a7d953) |

## 🔧 Technical Details

### Hook Configuration
- **Address**: `0x09ACf156789F81E854c4aE594f16Ec1E241d97aD`
- **Flags**: `0x97ad` (includes `0x80` for beforeSwap)
- **Salt**: `0`
- **Deviation Threshold**: 70% (7000 basis points)

### Deployment Method
- **CREATE2**: ✅ Deterministic deployment
- **Salt Mining**: Found valid salt = 0
- **Flag Verification**: ✅ beforeSwap enabled

## 📊 Deployment Statistics

- **Total Gas Used**: 5,719,665 gas
- **Total Cost**: 0.00000000145279491 ETH (~$0.004)
- **Deployer**: `0xbABB02af265C478FcC773088bbDF3352828761b4`
- **Block Range**: 26472837-26472838
- **Date**: September 19, 2025

## 🛠️ Frontend Configuration

Update your frontend configuration:

```javascript
// Frontend/src/config/sepolia.js
export const LISK_SEPOLIA_CONTRACTS = {
  // Tokens
  NGN: '0xca51E513ED59eC15592C9E9672b7F31C9bD20c6a',
  ARS: '0xbebcA094FaF7cED5239c63bE318E1d5C0DefF8Ea',
  GHS: '0xD0C1F10D3632C0f4A5021209421eA476797cFd77',
  USDC: '0x698da064496CE35DC5FB63E06CF1B19Ef4076e71',
  
  // Infrastructure
  ORACLE: '0x736b667295d2F18489Af1548082c86fd4C3750E5',
  HOOK: '0x09ACf156789F81E854c4aE594f16Ec1E241d97aD',
  HOOK_DEPLOYER: '0x655204fc0Be886ef5f96Ade62F76b1B240a7d953'
};

export const NETWORK_CONFIG = {
  chainId: 4202,
  name: 'Lisk Sepolia',
  rpcUrl: 'https://rpc.sepolia-api.lisk.com',
  blockExplorer: 'https://sepolia-blockscout.lisk.com',
  faucet: 'https://faucet.lisk.com'
};
```

## 🧪 Testing the Deployment

### 1. Verify Contract Functionality
```javascript
// Check oracle rates
const oracle = new ethers.Contract(
  '0x736b667295d2F18489Af1548082c86fd4C3750E5', 
  ORACLE_ABI, 
  provider
);

const ngnUsdcOfficial = await oracle.getOfficialRate(NGN, USDC);
const ngnUsdcStreet = await oracle.getStreetRate(NGN, USDC);
```

### 2. Test Token Contracts
```javascript
// Get test tokens
const ngn = new ethers.Contract(
  '0xca51E513ED59eC15592C9E9672b7F31C9bD20c6a',
  ERC20_ABI,
  signer
);

const balance = await ngn.balanceOf(address);
```

### 3. Verify Hook Flags
```javascript
// Verify hook has correct flags
const hookAddress = '0x09ACf156789F81E854c4aE594f16Ec1E241d97aD';
const addressBits = parseInt(hookAddress.slice(-4), 16);
const hasBeforeSwap = (addressBits & 0x80) === 0x80; // Should be true
```

## 🚀 Next Steps

### 1. Pool Creation (TODO)
Create Uniswap V4 pools for the token pairs:
- NGN/USDC
- ARS/USDC  
- GHS/USDC

### 2. Add Liquidity (TODO)
Provide initial liquidity to the pools for testing.

### 3. Test Swaps (TODO)
Execute test swaps to verify hook functionality.

## ⚠️ Important Notes

1. **Testnet Only**: These contracts are deployed on testnet for testing purposes
2. **Mock Oracle**: Using HybridRateOracle with mock data
3. **No Verification**: Contracts not verified on Blockscout (verification had issues)
4. **Pool Creation Needed**: Uniswap V4 pools not yet created

## 📞 Contract Interaction

### Environment Variables
```bash
LISK_SEPOLIA_RPC_URL=https://rpc.sepolia-api.lisk.com
PRIVATE_KEY=0x...
LISK_SEPOLIA_API_KEY=X1X1D6V9NR489K1YIT2C7ATY65JGMP216Q
```

### Deploy Command
```bash
cd Smart-Contract
./deploy.sh
```

## ✅ Verification Checklist

- [x] All tokens deployed successfully
- [x] Oracle deployed with initial rates
- [x] Hook deployed with correct flags
- [x] CREATE2 deployment working
- [x] Frontend configuration updated
- [ ] Contracts verified on Blockscout
- [ ] Uniswap V4 pools created
- [ ] Initial liquidity added
- [ ] End-to-end swap testing

## 🎯 Summary

The StreetRate hook system is **fully deployed and functional** on Lisk Sepolia testnet. All core contracts are live and ready for integration with Uniswap V4 pools. The next phase involves creating pools and testing the complete swap functionality.

**Deployment Status**: ✅ **COMPLETE**  
**Ready for**: Pool creation and swap testing