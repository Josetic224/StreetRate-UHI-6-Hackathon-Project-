// Sepolia Testnet Configuration
export const SEPOLIA_CHAIN_ID = 11155111;

export const SEPOLIA_RPC_URLS = [
  'https://sepolia.infura.io/v3/YOUR_INFURA_KEY',
  'https://rpc.sepolia.org',
  'https://ethereum-sepolia.publicnode.com',
  'https://sepolia.gateway.tenderly.co'
];

// Contract addresses (to be updated after deployment)
export const SEPOLIA_CONTRACTS = {
  // Tokens
  NGN: '0x0000000000000000000000000000000000000000',
  ARS: '0x0000000000000000000000000000000000000000',
  GHS: '0x0000000000000000000000000000000000000000',
  USDC: '0x0000000000000000000000000000000000000000',
  
  // Core contracts
  Oracle: '0x0000000000000000000000000000000000000000',
  PoolManager: '0x0000000000000000000000000000000000000000',
  Hook: '0x0000000000000000000000000000000000000000',
  
  // Routers
  SwapRouter: '0x0000000000000000000000000000000000000000',
  LiquidityRouter: '0x0000000000000000000000000000000000000000',
  
  // Pool IDs
  Pools: {
    'NGN/USDC': '0x0000000000000000000000000000000000000000000000000000000000000000',
    'ARS/USDC': '0x0000000000000000000000000000000000000000000000000000000000000000',
    'GHS/USDC': '0x0000000000000000000000000000000000000000000000000000000000000000'
  }
};

// Token metadata
export const TOKEN_INFO = {
  NGN: {
    symbol: 'NGN',
    name: 'Nigerian Naira',
    decimals: 18,
    flag: '🇳🇬',
    officialRate: 800,  // NGN per USD
    streetRate: 1500    // NGN per USD
  },
  ARS: {
    symbol: 'ARS',
    name: 'Argentine Peso',
    decimals: 18,
    flag: '🇦🇷',
    officialRate: 350,   // ARS per USD
    streetRate: 1000     // ARS per USD
  },
  GHS: {
    symbol: 'GHS',
    name: 'Ghanaian Cedi',
    decimals: 18,
    flag: '🇬🇭',
    officialRate: 12,    // GHS per USD
    streetRate: 15       // GHS per USD
  },
  USDC: {
    symbol: 'USDC',
    name: 'USD Coin',
    decimals: 6,
    flag: '💵'
  }
};

// Network configuration for wallet
export const SEPOLIA_NETWORK = {
  chainId: '0x' + SEPOLIA_CHAIN_ID.toString(16),
  chainName: 'Sepolia Testnet',
  nativeCurrency: {
    name: 'Sepolia ETH',
    symbol: 'ETH',
    decimals: 18
  },
  rpcUrls: SEPOLIA_RPC_URLS,
  blockExplorerUrls: ['https://sepolia.etherscan.io']
};
