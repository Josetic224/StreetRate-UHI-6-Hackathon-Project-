#!/bin/bash

# Load environment variables
source .env

echo "🚀 Deploying StreetRateHook to Sepolia Testnet..."
echo "================================================"

# Check if required env vars are set
if [ -z "$SEPOLIA_RPC_URL" ]; then
    echo "❌ Error: SEPOLIA_RPC_URL not set in .env"
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
echo "📡 RPC URL: $SEPOLIA_RPC_URL"
echo "🔑 Deployer: $(cast wallet address $PRIVATE_KEY)"

# Check balance
BALANCE=$(cast balance $(cast wallet address $PRIVATE_KEY) --rpc-url $SEPOLIA_RPC_URL)
echo "💰 Balance: $(cast from-wei $BALANCE) ETH"

# Check if balance is sufficient
MIN_BALANCE="10000000000000000" # 0.01 ETH in wei
if [ $(echo "$BALANCE < $MIN_BALANCE" | bc) -eq 1 ]; then
    echo "❌ Error: Insufficient balance. Need at least 0.01 ETH"
    echo "   Get testnet ETH from: https://sepoliafaucet.com"
    exit 1
fi

echo ""
echo "🔨 Starting deployment..."
echo ""

# Run deployment script
forge script script/DeployWithCreate2.s.sol \
    --tc DeployWithCreate2 \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    -vvv

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    echo "📄 Check deployments/sepolia.json for contract addresses"
else
    echo ""
    echo "❌ Deployment failed"
    exit 1
fi
