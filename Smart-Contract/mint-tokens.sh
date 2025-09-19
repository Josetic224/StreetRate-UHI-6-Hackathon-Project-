#!/bin/bash

# Load environment variables
source .env

# Your wallet address (replace with your actual address)
WALLET_ADDRESS="0xYourWalletAddressHere"

echo "🪙 Minting test tokens to $WALLET_ADDRESS..."

# Mint NGN tokens
echo "Minting NGN..."
cast send 0xca51E513ED59eC15592C9E9672b7F31C9bD20c6a \
    "mint(address,uint256)" \
    $WALLET_ADDRESS \
    1000000000000000000000000 \
    --rpc-url https://rpc.sepolia-api.lisk.com \
    --private-key $PRIVATE_KEY

# Mint ARS tokens  
echo "Minting ARS..."
cast send 0xbebcA094FaF7cED5239c63bE318E1d5C0DefF8Ea \
    "mint(address,uint256)" \
    $WALLET_ADDRESS \
    1000000000000000000000000 \
    --rpc-url https://rpc.sepolia-api.lisk.com \
    --private-key $PRIVATE_KEY

# Mint GHS tokens
echo "Minting GHS..."
cast send 0xD0C1F10D3632C0f4A5021209421eA476797cFd77 \
    "mint(address,uint256)" \
    $WALLET_ADDRESS \
    1000000000000000000000000 \
    --rpc-url https://rpc.sepolia-api.lisk.com \
    --private-key $PRIVATE_KEY

echo "✅ Tokens minted successfully!"
echo "Check balances:"
echo "NGN: $(cast call 0xca51E513ED59eC15592C9E9672b7F31C9bD20c6a 'balanceOf(address)' $WALLET_ADDRESS --rpc-url https://rpc.sepolia-api.lisk.com)"
echo "ARS: $(cast call 0xbebcA094FaF7cED5239c63bE318E1d5C0DefF8Ea 'balanceOf(address)' $WALLET_ADDRESS --rpc-url https://rpc.sepolia-api.lisk.com)"
echo "GHS: $(cast call 0xD0C1F10D3632C0f4A5021209421eA476797cFd77 'balanceOf(address)' $WALLET_ADDRESS --rpc-url https://rpc.sepolia-api.lisk.com)"