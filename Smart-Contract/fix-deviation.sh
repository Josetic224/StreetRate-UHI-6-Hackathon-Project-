#!/bin/bash

# Fix the deviation threshold to allow realistic street rate differences

echo "🔧 Updating deviation threshold in StreetRate Hook..."

# Update deviation threshold to 80% (8000 basis points) to allow realistic street rate differences
forge script script/FixDeviationScript.sol:FixDeviationScript \
  --chain 4202 \
  --rpc-url $LISK_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  -vvv

echo "✅ Deviation threshold update script executed!"