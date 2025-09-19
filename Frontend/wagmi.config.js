import { createConfig, http } from 'wagmi'
import { sepolia } from 'wagmi/chains'
import { connectorsForWallets } from '@rainbow-me/rainbowkit'
import {
  metaMaskWallet,
  walletConnectWallet,
  rainbowWallet,
} from '@rainbow-me/rainbowkit/wallets'

// Define Lisk Sepolia chain
const liskSepolia = {
  id: 4202,
  name: 'Lisk Sepolia',
  nativeCurrency: {
    decimals: 18,
    name: 'Ethereum',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: {
      http: ['https://rpc.sepolia-api.lisk.com'],
      webSocket: ['wss://ws.sepolia-api.lisk.com'],
    },
  },
  blockExplorers: {
    default: {
      name: 'Lisk Sepolia Blockscout',
      url: 'https://sepolia-blockscout.lisk.com',
    },
  },
  testnet: true,
}

const connectors = connectorsForWallets(
  [
    {
      groupName: 'Recommended',
      wallets: [
        metaMaskWallet,
        rainbowWallet,
        walletConnectWallet,
      ],
    },
  ],
  {
    appName: 'StreetRate',
    projectId: '59308b2b9ce121ae4723f72350dedcab', // Your WalletConnect project ID
  }
)

export const config = createConfig({
  chains: [liskSepolia, sepolia],
  connectors,
  transports: {
    [liskSepolia.id]: http('https://rpc.sepolia-api.lisk.com'),
    [sepolia.id]: http('https://rpc.sepolia.org'),
  },
})
