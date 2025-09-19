#!/bin/bash

# Load environment variables
source .env

echo "🔍 Verifying contracts on Lisk Sepolia Blockscout..."
echo "================================================"

# Contract addresses from deployment
NGN_ADDRESS="0xca51E513ED59eC15592C9E9672b7F31C9bD20c6a"
ARS_ADDRESS="0xbebcA094FaF7cED5239c63bE318E1d5C0DefF8Ea"
GHS_ADDRESS="0xD0C1F10D3632C0f4A5021209421eA476797cFd77"
USDC_ADDRESS="0x698da064496CE35DC5FB63E06CF1B19Ef4076e71"
ORACLE_ADDRESS="0x736b667295d2F18489Af1548082c86fd4C3750E5"
DEPLOYER_ADDRESS="0x655204fc0Be886ef5f96Ade62F76b1B240a7d953"
HOOK_ADDRESS="0x09ACf156789F81E854c4aE594f16Ec1E241d97aD"

echo "📋 Verifying deployed contracts..."
echo ""

# Verify FiatTokens
echo "🪙 Verifying NGN token..."
forge verify-contract $NGN_ADDRESS \
    src/tokens/FiatTokens.sol:FiatToken \
    --chain-id 4202 \
    --rpc-url $LISK_SEPOLIA_RPC_URL \
    --verifier blockscout \
    --verifier-url https://sepolia-blockscout.lisk.com/api \
    --constructor-args $(cast abi-encode "constructor(string,string)" "Nigerian Naira" "NGN") \
    || echo "❌ NGN verification failed"

echo "🪙 Verifying ARS token..."
forge verify-contract $ARS_ADDRESS \
    src/tokens/FiatTokens.sol:FiatToken \
    --chain-id 4202 \
    --rpc-url $LISK_SEPOLIA_RPC_URL \
    --verifier blockscout \
    --verifier-url https://sepolia-blockscout.lisk.com/api \
    --constructor-args $(cast abi-encode "constructor(string,string)" "Argentine Peso" "ARS") \
    || echo "❌ ARS verification failed"

echo "🪙 Verifying GHS token..."
forge verify-contract $GHS_ADDRESS \
    src/tokens/FiatTokens.sol:FiatToken \
    --chain-id 4202 \
    --rpc-url $LISK_SEPOLIA_RPC_URL \
    --verifier blockscout \
    --verifier-url https://sepolia-blockscout.lisk.com/api \
    --constructor-args $(cast abi-encode "constructor(string,string)" "Ghanaian Cedi" "GHS") \
    || echo "❌ GHS verification failed"

echo "🪙 Verifying USDC token..."
forge verify-contract $USDC_ADDRESS \
    src/tokens/FiatTokens.sol:FiatToken \
    --chain-id 4202 \
    --rpc-url $LISK_SEPOLIA_RPC_URL \
    --verifier blockscout \
    --verifier-url https://sepolia-blockscout.lisk.com/api \
    --constructor-args $(cast abi-encode "constructor(string,string)" "USD Coin" "USDC") \
    || echo "❌ USDC verification failed"

echo "🔮 Verifying Oracle..."
forge verify-contract $ORACLE_ADDRESS \
    src/HybridRateOracle.sol:HybridRateOracle \
    --chain-id 4202 \
    --rpc-url $LISK_SEPOLIA_RPC_URL \
    --verifier blockscout \
    --verifier-url https://sepolia-blockscout.lisk.com/api \
    || echo "❌ Oracle verification failed"

echo "🚀 Verifying Hook Deployer..."
forge verify-contract $DEPLOYER_ADDRESS \
    src/HookDeployer.sol:HookDeployer \
    --chain-id 4202 \
    --rpc-url $LISK_SEPOLIA_RPC_URL \
    --verifier blockscout \
    --verifier-url https://sepolia-blockscout.lisk.com/api \
    || echo "❌ Deployer verification failed"

echo "🎣 Verifying StreetRate Hook..."
forge verify-contract $HOOK_ADDRESS \
    src/StreetRateHookStandalone.sol:StreetRateHookStandalone \
    --chain-id 4202 \
    --rpc-url $LISK_SEPOLIA_RPC_URL \
    --verifier blockscout \
    --verifier-url https://sepolia-blockscout.lisk.com/api \
    --constructor-args $(cast abi-encode "constructor(address,uint256)" $ORACLE_ADDRESS 7000) \
    || echo "❌ Hook verification failed"

echo ""
echo "✅ Verification process completed!"
echo "📄 Check contracts on Lisk Sepolia Blockscout:"
echo "   https://sepolia-blockscout.lisk.com"
echo ""
echo "🎣 Main Hook Contract: https://sepolia-blockscout.lisk.com/address/$HOOK_ADDRESS"