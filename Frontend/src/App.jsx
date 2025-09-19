import { useState, useEffect } from 'react';
import WalletConnection from './components/WalletConnection';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACT_ADDRESSES } from './config/sepolia';
import { parseUnits, formatUnits } from 'viem';

// ERC20 ABI for token operations
const ERC20_ABI = [
  {
    "inputs": [{"name": "spender", "type": "address"}, {"name": "amount", "type": "uint256"}],
    "name": "approve",
    "outputs": [{"name": "", "type": "bool"}],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"name": "account", "type": "address"}],
    "name": "balanceOf",
    "outputs": [{"name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"name": "owner", "type": "address"}, {"name": "spender", "type": "address"}],
    "name": "allowance",
    "outputs": [{"name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "mint",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
];
const ORACLE_ABI = [
  {
    "inputs": [
      {"name": "base", "type": "address"},
      {"name": "quote", "type": "address"}
    ],
    "name": "getOfficialRate",
    "outputs": [{"name": "rate", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {"name": "base", "type": "address"},
      {"name": "quote", "type": "address"}
    ],
    "name": "getStreetRate",
    "outputs": [{"name": "rate", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {"name": "base", "type": "address"},
      {"name": "quote", "type": "address"}
    ],
    "name": "isPairSupported",
    "outputs": [{"name": "supported", "type": "bool"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {"name": "base", "type": "address"},
      {"name": "quote", "type": "address"}
    ],
    "name": "getDeviation",
    "outputs": [{"name": "deviation", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  }
];

// Hook ABI for StreetRateHookStandalone
const HOOK_ABI = [
  {
    "inputs": [
      {"name": "tokenIn", "type": "address"},
      {"name": "tokenOut", "type": "address"},
      {"name": "amountIn", "type": "uint256"},
      {"name": "isExactInput", "type": "bool"}
    ],
    "name": "executeSwap",
    "outputs": [{"name": "amountOut", "type": "uint256"}],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"name": "tokenIn", "type": "address"},
      {"name": "tokenOut", "type": "address"},
      {"name": "amountIn", "type": "uint256"},
      {"name": "isExactInput", "type": "bool"}
    ],
    "name": "previewSwap",
    "outputs": [{"name": "amountOut", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  }
];

const CURRENCIES = [
  { 
    code: 'NGN', 
    name: 'Nigerian Naira', 
    symbol: '₦',
    address: CONTRACT_ADDRESSES.NGN,
    decimals: 18
  },
  { 
    code: 'ARS', 
    name: 'Argentine Peso', 
    symbol: '$',
    address: CONTRACT_ADDRESSES.ARS,
    decimals: 18
  },
  { 
    code: 'GHS', 
    name: 'Ghanaian Cedi', 
    symbol: '₵',
    address: CONTRACT_ADDRESSES.GHS,
    decimals: 18
  }
];



export default function App() {
  const { isConnected, address } = useAccount();
  const [selectedCurrency, setSelectedCurrency] = useState(CURRENCIES[0]);
  const [amount, setAmount] = useState('');
  const [outputAmount, setOutputAmount] = useState(null);
  const [isSwapping, setIsSwapping] = useState(false);
  const [needsApproval, setNeedsApproval] = useState(false);
  const [isMinting, setIsMinting] = useState(false);
  
  // Write contract hooks
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({ hash });
  
  // Get token balance
  const { data: tokenBalance } = useReadContract({
    address: selectedCurrency.address,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [address],
    enabled: isConnected && !!address
  });
  
  // Get token allowance
  const { data: tokenAllowance } = useReadContract({
    address: selectedCurrency.address,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: [address, CONTRACT_ADDRESSES.HOOK],
    enabled: isConnected && !!address
  });
  
  // Check if approval is needed
  useEffect(() => {
    if (amount && tokenAllowance) {
      const amountWei = parseUnits(amount, selectedCurrency.decimals);
      setNeedsApproval(tokenAllowance < amountWei);
    } else {
      setNeedsApproval(false);
    }
  }, [amount, tokenAllowance, selectedCurrency.decimals]);
  const { data: officialRateData, isLoading: isOfficialRateLoading } = useReadContract({
    address: CONTRACT_ADDRESSES.ORACLE,
    abi: ORACLE_ABI,
    functionName: 'getOfficialRate',
    args: [selectedCurrency.address, CONTRACT_ADDRESSES.USDC],
    enabled: isConnected
  });
  
  // Get street rate from oracle
  const { data: streetRateData, isLoading: isStreetRateLoading } = useReadContract({
    address: CONTRACT_ADDRESSES.ORACLE,
    abi: ORACLE_ABI,
    functionName: 'getStreetRate',
    args: [selectedCurrency.address, CONTRACT_ADDRESSES.USDC],
    enabled: isConnected
  });
  
  // Calculate swap output using preview function
  const { data: previewData } = useReadContract({
    address: CONTRACT_ADDRESSES.HOOK,
    abi: HOOK_ABI,
    functionName: 'previewSwap',
    args: [
      selectedCurrency.address, 
      CONTRACT_ADDRESSES.USDC, 
      amount ? parseUnits(amount, selectedCurrency.decimals) : 0n,
      true // isExactInput
    ],
    enabled: isConnected && amount && !isNaN(Number(amount)) && Number(amount) > 0
  });
  
  // Update output amount when preview data changes
  useEffect(() => {
    if (previewData) {
      setOutputAmount(formatUnits(previewData, 6)); // USDC has 6 decimals
    } else {
      setOutputAmount(null);
    }
  }, [previewData]);
  
  // Mint tokens function
  const handleMint = async () => {
    if (!selectedCurrency.address || isMinting || !address) return;
    
    setIsMinting(true);
    try {
      // Mint 1,000,000 tokens to the user
      const mintAmount = parseUnits('1000000', selectedCurrency.decimals);
      await writeContract({
        address: selectedCurrency.address,
        abi: ERC20_ABI,
        functionName: 'mint',
        args: [address, mintAmount]
      });
    } catch (error) {
      console.error('Mint failed:', error);
    } finally {
      setIsMinting(false);
    }
  };
  
  // Approve tokens function
  const handleApprove = async () => {
    if (!amount || !selectedCurrency.address) return;
    
    try {
      const amountWei = parseUnits(amount, selectedCurrency.decimals);
      await writeContract({
        address: selectedCurrency.address,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [CONTRACT_ADDRESSES.HOOK, amountWei]
      });
    } catch (error) {
      console.error('Approval failed:', error);
    }
  };
  const handleSwap = async () => {
    if (!amount || !selectedCurrency.address || isSwapping) return;
    
    setIsSwapping(true);
    try {
      await writeContract({
        address: CONTRACT_ADDRESSES.HOOK,
        abi: HOOK_ABI,
        functionName: 'executeSwap',
        args: [
          selectedCurrency.address,
          CONTRACT_ADDRESSES.USDC,
          parseUnits(amount, selectedCurrency.decimals),
          true // isExactInput
        ]
      });
    } catch (error) {
      console.error('Swap failed:', error);
    } finally {
      setIsSwapping(false);
    }
  };
  
  // Reset form when transaction is confirmed
  useEffect(() => {
    if (isConfirmed) {
      setAmount('');
      setOutputAmount(null);
    }
  }, [isConfirmed]);
  
  const rateDifference = streetRateData && officialRateData ? 
    ((Number(streetRateData) - Number(officialRateData)) / Number(officialRateData)) * 100 : 0;
  
  return (
    <div className="min-h-screen bg-web3-dark text-web3-light">
      <WalletConnection />
      
      <main className="container mx-auto px-4 py-8">
        <div className="text-center mb-12">
          <h1 className="text-4xl font-bold mb-4 bg-clip-text text-transparent bg-gradient-to-r from-web3-purple to-web3-light">
            StreetRate Swap
          </h1>
          <p className="text-xl text-gray-400 max-w-2xl mx-auto">
            Experience the power of decentralized finance with real-world exchange rates
          </p>
          
          {/* Quick Debug */}
          <div className="mt-4 p-3 bg-gray-800 rounded-lg text-sm">
            <div>Wallet Connected: {isConnected ? '✅' : '❌'}</div>
            <div>Address: {address || 'Not connected'}</div>
            <div>Selected Currency: {selectedCurrency.code}</div>
            <div>Token Address: {selectedCurrency.address}</div>
          </div>
        </div>
        
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Swap Interface */}
          <div className="lg:col-span-2">
            <div className="bg-web3-dark border border-gray-800 rounded-2xl p-6 shadow-xl">
              <div className="mb-6">
                <label className="block text-sm font-medium mb-2">Currency</label>
                <select 
                  value={selectedCurrency.code}
                  onChange={(e) => {
                    const currency = CURRENCIES.find(c => c.code === e.target.value);
                    setSelectedCurrency(currency);
                  }}
                  className="w-full bg-gray-800 border border-gray-700 rounded-lg p-3 text-web3-light focus:outline-none focus:ring-2 focus:ring-web3-purple"
                >
                  {CURRENCIES.map(currency => (
                    <option key={currency.code} value={currency.code}>
                      {currency.name} ({currency.symbol})
                    </option>
                  ))}
                </select>
              </div>
              
              {/* MINT SECTION - Always visible */}
              <div className="mb-6 p-4 bg-green-900/20 border border-green-700 rounded-lg">
                <h3 className="text-green-300 font-medium mb-2">🪙 Get Test Tokens</h3>
                <button
                  onClick={handleMint}
                  disabled={!isConnected || isMinting || isPending}
                  className="w-full py-2 bg-green-600 hover:bg-green-700 disabled:bg-gray-600 rounded-lg text-sm font-medium transition-all"
                >
                  {!isConnected ? 'Connect Wallet First' :
                   isMinting || isPending ? 'Minting...' : 
                   `Mint 1,000,000 ${selectedCurrency.code} Tokens`}
                </button>
                <div className="mt-2 text-xs text-green-200">
                  Balance: {tokenBalance ? formatUnits(tokenBalance, selectedCurrency.decimals) : '0'} {selectedCurrency.code}
                </div>
              </div>
              
              <div className="mb-6">
                <div className="flex justify-between items-center mb-2">
                  <label className="block text-sm font-medium">Amount ({selectedCurrency.code})</label>
                  <div className="text-sm text-gray-400">
                    Balance: {tokenBalance ? formatUnits(tokenBalance, selectedCurrency.decimals) : '0'} {selectedCurrency.code}
                  </div>
                </div>
                <div className="relative">
                  <input
                    type="number"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    placeholder="0.00"
                    className="w-full bg-gray-800 border border-gray-700 rounded-lg p-3 text-web3-light focus:outline-none focus:ring-2 focus:ring-web3-purple"
                  />
                  <div className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400">
                    {selectedCurrency.code}
                  </div>
                </div>
                
                {/* Always show mint button for testing */}
                <button
                  onClick={handleMint}
                  disabled={isMinting || isPending || !address}
                  className="mt-2 w-full py-2 bg-green-600 hover:bg-green-700 disabled:bg-gray-600 rounded-lg text-sm font-medium transition-all"
                >
                  {isMinting || isPending ? 'Minting...' : `Mint 1,000,000 ${selectedCurrency.code} Tokens`}
                </button>
                
                {/* Debug info */}
                <div className="mt-2 p-2 bg-gray-900 rounded text-xs text-gray-400">
                  <div>Connected: {isConnected ? '✅' : '❌'}</div>
                  <div>Address: {address || 'Not connected'}</div>
                  <div>Token Balance: {tokenBalance !== undefined ? formatUnits(tokenBalance || 0n, selectedCurrency.decimals) : 'Loading...'}</div>
                  <div>Token Contract: {selectedCurrency.address}</div>
                </div>
              </div>
              
              <div className="space-y-4 mb-6">
                <div className="flex justify-between items-center p-4 bg-gray-800 rounded-lg">
                  <span className="text-gray-400">Official Rate</span>
                  <span className="font-medium">
                    {isOfficialRateLoading ? 'Loading...' : 
                      officialRateData ? 
                        `1 ${selectedCurrency.symbol} = ${Number(formatUnits(officialRateData, 18)).toFixed(6)} USDC` : 
                        'N/A'}
                  </span>
                </div>
                
                <div className="flex justify-between items-center p-4 bg-gray-800 rounded-lg">
                  <span className="text-gray-400">Street Rate</span>
                  <span className="font-medium text-web3-purple">
                    {isStreetRateLoading ? 'Loading...' : 
                      streetRateData ? 
                        `1 ${selectedCurrency.symbol} = ${Number(formatUnits(streetRateData, 18)).toFixed(6)} USDC` : 
                        'N/A'}
                  </span>
                </div>
                
                <div className="flex justify-between items-center p-4 bg-gray-800 rounded-lg">
                  <span className="text-gray-400">Rate Difference</span>
                  <span className={`font-medium ${rateDifference > 0 ? 'text-green-400' : 'text-red-400'}`}>
                    {rateDifference > 0 ? '+' : ''}{rateDifference.toFixed(2)}%
                  </span>
                </div>
              </div>
              
              {/* Approve/Swap buttons */}
              {needsApproval ? (
                <button 
                  onClick={handleApprove}
                  disabled={!isConnected || !amount || isPending || isConfirming}
                  className={`w-full py-3 rounded-lg font-medium text-lg transition-all ${
                    !isConnected || !amount || isPending || isConfirming
                      ? 'bg-gray-700 cursor-not-allowed'
                      : 'bg-yellow-600 hover:bg-yellow-700'
                  }`}
                >
                  {isPending ? 'Approving...' : 'Approve Tokens'}
                </button>
              ) : (
                <button 
                  onClick={handleSwap}
                  disabled={!isConnected || !amount || !streetRateData || isSwapping || isPending || isConfirming || !tokenBalance || tokenBalance === 0n}
                  className={`w-full py-3 rounded-lg font-medium text-lg transition-all ${
                    !isConnected || !amount || !streetRateData || isSwapping || isPending || isConfirming || !tokenBalance || tokenBalance === 0n
                      ? 'bg-gray-700 cursor-not-allowed'
                      : 'bg-web3-purple hover:bg-purple-600'
                  }`}
                >
                  {!isConnected ? 'Connect Wallet to Swap' :
                   !tokenBalance || tokenBalance === 0n ? `Mint ${selectedCurrency.code} Tokens First` :
                   isSwapping || isPending ? 'Confirming...' :
                   isConfirming ? 'Processing...' :
                   'Swap'}
                </button>
              )}
            </div>
            
            {outputAmount && (
              <div className="mt-4 p-4 bg-gray-800 border border-gray-700 rounded-lg">
                <div className="flex justify-between">
                  <span className="text-gray-400">You will receive</span>
                  <span className="font-bold text-web3-purple">
                    {outputAmount} USDC
                  </span>
                </div>
              </div>
            )}
            
            {/* Debug Info - Remove in production */}
            {isConnected && (
              <div className="mt-4 p-4 bg-gray-900 border border-gray-700 rounded-lg text-xs">
                <h4 className="text-gray-300 font-medium mb-2">Debug Info:</h4>
                <div className="space-y-1 text-gray-400">
                  <div>Connected: {isConnected ? 'Yes' : 'No'}</div>
                  <div>Address: {address}</div>
                  <div>Selected Currency: {selectedCurrency.code}</div>
                  <div>Token Balance: {tokenBalance ? formatUnits(tokenBalance, selectedCurrency.decimals) : 'Loading...'}</div>
                  <div>Token Allowance: {tokenAllowance ? formatUnits(tokenAllowance, selectedCurrency.decimals) : 'Loading...'}</div>
                  <div>Official Rate: {officialRateData ? formatUnits(officialRateData, 18) : 'Loading...'}</div>
                  <div>Street Rate: {streetRateData ? formatUnits(streetRateData, 18) : 'Loading...'}</div>
                  <div>Amount: {amount}</div>
                  <div>Preview Output: {previewData ? formatUnits(previewData, 6) : 'N/A'}</div>
                  <div>Needs Approval: {needsApproval ? 'Yes' : 'No'}</div>
                </div>
              </div>
            )}
            <div className="mt-4 p-4 bg-blue-900/30 border border-blue-700 rounded-lg">
              <h3 className="text-sm font-medium text-blue-300 mb-2">How to Swap:</h3>
              <ol className="text-xs text-blue-200 space-y-1">
                <li>1. Connect your wallet to Lisk Sepolia</li>
                <li>2. Get test ETH from <a href="https://faucet.lisk.com" target="_blank" className="underline">Lisk Faucet</a></li>
                <li>3. Mint tokens using the "Mint" button</li>
                <li>4. Approve tokens for the hook contract</li>
                <li>5. Execute the swap to see street rates in action!</li>
              </ol>
            </div>
            {(isPending || isConfirming || isConfirmed || error) && (
              <div className="mt-4 p-4 bg-gray-800 border border-gray-700 rounded-lg">
                {isPending && (
                  <div className="text-yellow-400">⏳ Waiting for confirmation...</div>
                )}
                {isConfirming && (
                  <div className="text-blue-400">🔄 Processing transaction...</div>
                )}
                {isConfirmed && (
                  <div className="text-green-400">✅ Swap completed successfully!</div>
                )}
                {error && (
                  <div className="text-red-400">❌ Error: {error.shortMessage || error.message}</div>
                )}
                {hash && (
                  <div className="mt-2 text-sm text-gray-400">
                    Transaction: 
                    <a 
                      href={`https://sepolia-blockscout.lisk.com/tx/${hash}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-web3-purple hover:underline ml-1"
                    >
                      {hash.slice(0, 10)}...{hash.slice(-8)}
                    </a>
                  </div>
                )}
              </div>
            )}
          </div>
          
          {/* Rate Visualization */}
          <div>
            <div className="bg-web3-dark border border-gray-800 rounded-2xl p-6 shadow-xl h-full">
              <h2 className="text-xl font-bold mb-4">Rate Comparison</h2>
              
              <div className="space-y-6">
                <div>
                  <div className="flex justify-between mb-1">
                    <span className="text-gray-400">Official Rate</span>
                    <span>
                      {officialRateData ? 
                        `${Number(formatUnits(officialRateData, 18)).toFixed(6)} USDC` : 
                        'N/A'}
                    </span>
                  </div>
                  <div className="h-2 bg-gray-800 rounded-full overflow-hidden">
                    <div 
                      className="h-full bg-gray-500"
                      style={{ width: '100%' }}
                    ></div>
                  </div>
                </div>
                
                <div>
                  <div className="flex justify-between mb-1">
                    <span className="text-gray-400">Street Rate</span>
                    <span className="text-web3-purple">
                      {streetRateData ? 
                        `${Number(formatUnits(streetRateData, 18)).toFixed(6)} USDC` : 
                        'N/A'}
                    </span>
                  </div>
                  <div className="h-2 bg-gray-800 rounded-full overflow-hidden">
                    <div 
                      className="h-full bg-web3-purple"
                      style={{ 
                        width: streetRateData && officialRateData ? 
                          `${Math.min(100, Number(streetRateData) / Number(officialRateData) * 100)}%` : 
                          '0%' 
                      }}
                    ></div>
                  </div>
                </div>
                
                <div className="mt-8">
                  <h3 className="font-medium mb-3">Rate Difference</h3>
                  <div className="relative h-32 bg-gray-800 rounded-lg p-2">
                    <div className="absolute bottom-0 left-0 w-full h-1 bg-gray-700"></div>
                    
                    <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-0.5 h-full bg-gray-600"></div>
                    
                    <div 
                      className={`absolute bottom-0 w-12 rounded-t transition-all duration-300 ${
                        rateDifference > 0 ? 'bg-green-500' : 'bg-red-500'
                      }`}
                      style={{ 
                        left: '50%',
                        marginLeft: rateDifference > 0 ? '0' : `-${Math.abs(rateDifference) * 0.5}px`,
                        height: `${Math.abs(rateDifference) * 2}px`
                      }}
                    ></div>
                    
                    <div className="absolute bottom-4 left-1/2 -translate-x-1/2 text-sm font-medium">
                      {rateDifference > 0 ? '+' : ''}{rateDifference.toFixed(1)}%
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        
        {/* Transaction History */}
        <div className="mt-12">
          <div className="bg-web3-dark border border-gray-800 rounded-2xl p-6 shadow-xl">
            <h2 className="text-xl font-bold mb-4">Transaction History</h2>
            
            <div className="space-y-4">
              <div className="p-4 bg-gray-800 rounded-lg">
                <div className="flex justify-between items-start">
                  <div>
                    <p className="font-medium">Swap NGN</p>
                    <p className="text-sm text-gray-400">15 min ago</p>
                  </div>
                  <span className="text-green-400">+1,250.50 NGN</span>
                </div>
              </div>
              
              <div className="p-4 bg-gray-800 rounded-lg">
                <div className="flex justify-between items-start">
                  <div>
                    <p className="font-medium">Swap ARS</p>
                    <p className="text-sm text-gray-400">45 min ago</p>
                  </div>
                  <span className="text-green-400">+8,750.25 ARS</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
      
      <footer className="container mx-auto px-4 py-8 text-center text-gray-500">
        <p>StreetRate - Bridging the gap between official and street exchange rates</p>
      </footer>
    </div>
  );
}
