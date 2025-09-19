#!/bin/bash

# Fix the deviation threshold to allow realistic street rate differences

echo "🔧 Updating deviation threshold in StreetRate Hook..."

# Hook contract address
HOOK_ADDRESS="0x09ACf156789F81E854c4aE594f16Ec1E241d97aD"

# Update deviation threshold to 8000 basis points (80%) using cast
cast send $HOOK_ADDRESS \
  "updateDeviationThreshold(uint256)" \
  8000 \
  --rpc-url $LISK_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

echo "✅ Deviation threshold updated to 80%!"

# Verify the update
echo "📊 Checking current deviation threshold..."
cast call $HOOK_ADDRESS \
  "deviationThreshold()(uint256)" \
  --rpc-url $LISK_SEPOLIA_RPC_URL

echo "✅ Done!"