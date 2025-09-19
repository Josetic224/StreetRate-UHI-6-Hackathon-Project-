#!/bin/bash

# Load environment variables
source .env

# Debug variable loading
echo "🔍 Debug: Loading environment variables"
echo "LISK_SEPOLIA_RPC_URL: $LISK_SEPOLIA_RPC_URL"
echo "PRIVATE_KEY: $PRIVATE_KEY"
echo "LISK_SEPOLIA_API_KEY: $LISK_SEPOLIA_API_KEY"

echo "🚀 Deploying StreetRateHook to Lisk Sepolia Testnet..."
echo "================================================"

# Check if required env vars are set
if [ -z "$LISK_SEPOLIA_RPC_URL" ]; then
    echo "❌ Error: LISK_SEPOLIA_RPC_URL not set in .env"
    echo "   Set LISK_SEPOLIA_RPC_URL=https://rpc.sepolia-api.lisk.com in .env"
    exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ Error: PRIVATE_KEY not set in .env"
    exit 1
fi

# Check if PRIVATE_KEY has 0x prefix
if [[ ! "$PRIVATE_KEY" =~ ^0x ]]; then
    echo "❌ Error: PRIVATE_KEY must start with 0x"
    exit 1
fi

echo "✅ Environment variables loaded"
echo "📡 RPC URL: $LISK_SEPOLIA_RPC_URL"
echo "🔑 Deployer: $(cast wallet address $PRIVATE_KEY)"

# Check balance
BALANCE=$(cast balance $(cast wallet address $PRIVATE_KEY) --rpc-url $LISK_SEPOLIA_RPC_URL)
echo "💰 Balance: $(cast from-wei $BALANCE) ETH"

# Check if balance is sufficient
MIN_BALANCE="10000000000000000" # 0.01 ETH in wei
if [ $(echo "$BALANCE < $MIN_BALANCE" | bc) -eq 1 ]; then
    echo "❌ Error: Insufficient balance. Need at least 0.01 ETH"
    echo "   Get testnet ETH from: https://faucet.lisk.com"
    exit 1
fi

echo ""
echo "🔨 Starting deployment..."
echo ""

# Run deployment script
forge script script/DeployWithCreate2.s.sol:DeployWithCreate2 \
    --rpc-url $LISK_SEPOLIA_RPC_URL \
    --chain-id 4202 \
    --broadcast \
    --verify \
    --verifier blockscout \
    --verifier-url https://sepolia-blockscout.lisk.com/api \
    -vvv

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    echo "📄 Check deployments/lisk-sepolia.json for contract addresses"
else
    echo ""
    echo "❌ Deployment failed"
    exit 1
fi
