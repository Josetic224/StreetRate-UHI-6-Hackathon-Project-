# 🚀 Sepolia Testnet Deployment Guide

## Prerequisites

### 1. Environment Setup
Create a `.env` file in the `Smart-Contract` directory with:

```bash
# IMPORTANT: PRIVATE_KEY must have 0x prefix!
PRIVATE_KEY=0x<your_private_key_here>
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/<your_infura_key>
ETHERSCAN_API_KEY=<your_etherscan_api_key>
```

### 2. Get Testnet ETH
You need at least 0.01 Sepolia ETH. Get it from:
- [Sepolia Faucet](https://sepoliafaucet.com)
- [Alchemy Faucet](https://sepoliafaucet.com)
- [Infura Faucet](https://www.infura.io/faucet/sepolia)

### 3. Verify Setup
```bash
cd Smart-Contract
source .env
cast wallet address $PRIVATE_KEY  # Shows your deployer address
cast balance $(cast wallet address $PRIVATE_KEY) --rpc-url $SEPOLIA_RPC_URL
```

## 🎯 Deployment Process

### Option 1: Using Deploy Script (Recommended)
```bash
cd Smart-Contract
./deploy.sh
```

### Option 2: Manual Deployment
```bash
cd Smart-Contract
source .env
forge script script/DeployToSepolia.s.sol \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    -vvv
```

## 📋 What Gets Deployed

1. **Mock Tokens**
   - NGN (Nigerian Naira) - 18 decimals
   - ARS (Argentine Peso) - 18 decimals
   - GHS (Ghanaian Cedi) - 18 decimals
   - USDC (Mock USD Coin) - 6 decimals

2. **Core Contracts**
   - HybridRateOracle - Multi-currency oracle
   - PoolManager - Uniswap V4 pool manager
   - StreetRateHookV4Simple - Hook with CREATE2

3. **Routers**
   - ModifyLiquidityRouter - For adding/removing liquidity
   - SwapRouter - For executing swaps

4. **Pools Created**
   - NGN/USDC pool
   - ARS/USDC pool
   - GHS/USDC pool

## 🔍 Post-Deployment Verification

### 1. Check Deployment Addresses
```bash
cat deployments/sepolia.json
```

### 2. Verify on Etherscan
All contracts should be auto-verified if ETHERSCAN_API_KEY is set.
Check at: https://sepolia.etherscan.io/address/<contract_address>

### 3. Test a Swap
```bash
cd Smart-Contract
forge script script/TestSepoliaSwap.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast
```

## 🧪 Running Integration Tests

### Fork Sepolia for Testing
```bash
forge test --match-path test/SepoliaIntegration.t.sol \
    --fork-url $SEPOLIA_RPC_URL \
    -vvv
```

### Gas Report
```bash
forge test --match-path test/SepoliaIntegration.t.sol \
    --fork-url $SEPOLIA_RPC_URL \
    --gas-report
```

## 💻 Frontend Integration

### 1. Update Contract Addresses
After deployment, update `Frontend/src/config/sepolia.js` with the deployed addresses from `deployments/sepolia.json`.

### 2. Connect Frontend
```javascript
// In your React app
import { SEPOLIA_CONTRACTS } from './config/sepolia';

// Use the deployed addresses
const oracle = new ethers.Contract(
  SEPOLIA_CONTRACTS.Oracle,
  ORACLE_ABI,
  provider
);
```

### 3. Test Swap Flow
1. Connect MetaMask to Sepolia
2. Select tokens (NGN → USDC)
3. Enter amount
4. Approve tokens
5. Execute swap
6. Monitor events

## 📊 Expected Gas Costs

| Operation | Estimated Gas | Cost (30 Gwei) |
|-----------|---------------|----------------|
| Token Deployment | ~800k each | 0.024 ETH |
| Oracle Deployment | ~1.5M | 0.045 ETH |
| Hook Deployment | ~1M | 0.03 ETH |
| Pool Creation | ~200k each | 0.006 ETH |
| **Total Deployment** | ~6M | ~0.18 ETH |
| Single Swap | ~150k | 0.0045 ETH |

## 🐛 Troubleshooting

### "Insufficient balance" Error
- Get more Sepolia ETH from faucets
- Minimum needed: 0.2 ETH for full deployment

### "PRIVATE_KEY missing 0x prefix" Error
- Ensure your private key starts with `0x` in the .env file

### "Hook address mismatch" Error
- The CREATE2 salt mining failed
- Try running deployment again

### "Pool already initialized" Error
- Pools already exist at those addresses
- Deploy with different parameters or use existing pools

## 📝 Deployment Checklist

- [ ] .env file configured with all required variables
- [ ] PRIVATE_KEY has 0x prefix
- [ ] Account funded with at least 0.2 Sepolia ETH
- [ ] Foundry installed and updated
- [ ] Internet connection stable (deployment takes ~5 minutes)
- [ ] Etherscan API key for verification (optional)

## 🎉 Success Indicators

When deployment succeeds, you'll see:
1. All contract addresses printed in console
2. `deployments/sepolia.json` file created
3. Contracts verified on Sepolia Etherscan
4. Pools initialized and ready for swaps
5. Test tokens minted to deployer address

## 📚 Next Steps

1. **Test Swaps**: Execute test swaps through the pools
2. **Add Liquidity**: Provide liquidity to enable larger swaps
3. **Frontend Testing**: Connect the React frontend
4. **Monitor Events**: Watch for RateChecked and SwapExecuted events
5. **Share Demo**: Share testnet addresses for others to test

## 🔗 Useful Links

- [Sepolia Etherscan](https://sepolia.etherscan.io)
- [Sepolia Faucet](https://sepoliafaucet.com)
- [Uniswap V4 Docs](https://docs.uniswap.org/contracts/v4/overview)
- [Foundry Book](https://book.getfoundry.sh)

---

**Ready to Deploy?** Run `./deploy.sh` and watch your multi-currency StreetRateHook system come to life on Sepolia! 🚀
