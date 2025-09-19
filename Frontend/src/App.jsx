import { useState, useEffect } from 'react';
import WalletConnection from './components/WalletConnection';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACT_ADDRESSES } from './config/sepolia';
import { parseUnits, formatUnits } from 'viem';

// Simplified ERC20 ABI
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
    "inputs": [{"name": "to", "type": "address"}, {"name": "amount", "type": "uint256"}],
    "name": "mint",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
];

// Simplified Oracle ABI
const ORACLE_ABI = [
  {
    "inputs": [{"name": "base", "type": "address"}, {"name": "quote", "type": "address"}],
    "name": "getStreetRate",
    "outputs": [{"name": "rate", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"name": "base", "type": "address"}, {"name": "quote", "type": "address"}],
    "name": "getOfficialRate",
    "outputs": [{"name": "rate", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  }
];

// Hook ABI for swapping
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
  const [isMinting, setIsMinting] = useState(false);
  const [isSwapping, setIsSwapping] = useState(false);
  const [needsApproval, setNeedsApproval] = useState(false);
  const [transactions, setTransactions] = useState([]);
  const [notification, setNotification] = useState(null);
  
  const { writeContract, isPending, data: hash } = useWriteContract();
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
  
  // Get street rate
  const { data: streetRateData } = useReadContract({
    address: CONTRACT_ADDRESSES.ORACLE,
    abi: ORACLE_ABI,
    functionName: 'getStreetRate',
    args: [selectedCurrency.address, CONTRACT_ADDRESSES.USDC],
    enabled: isConnected
  });
  
  // Get official rate
  const { data: officialRateData } = useReadContract({
    address: CONTRACT_ADDRESSES.ORACLE,
    abi: ORACLE_ABI,
    functionName: 'getOfficialRate',
    args: [selectedCurrency.address, CONTRACT_ADDRESSES.USDC],
    enabled: isConnected
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
  
  // Calculate output amount
  useEffect(() => {
    if (amount && streetRateData && !isNaN(Number(amount)) && Number(amount) > 0) {
      try {
        const amountWei = parseUnits(amount, selectedCurrency.decimals);
        const outputWei = (amountWei * streetRateData) / parseUnits('1', 18);
        const outputFormatted = formatUnits(outputWei, 6);
        setOutputAmount(outputFormatted);
      } catch (error) {
        console.error('Calculation error:', error);
        setOutputAmount(null);
      }
    } else {
      setOutputAmount(null);
    }
  }, [amount, streetRateData, selectedCurrency.decimals]);
  
  // Show notification
  const showNotification = (message, type = 'info') => {
    setNotification({ message, type, id: Date.now() });
    setTimeout(() => setNotification(null), 5000);
  };
  
  // Handle transaction confirmation
  useEffect(() => {
    if (hash) {
      showNotification(`Transaction submitted! Hash: ${hash.slice(0, 10)}...`, 'info');
    }
    if (isConfirming) {
      showNotification('Confirming transaction...', 'pending');
    }
    if (isConfirmed) {
      showNotification('Transaction confirmed successfully! 🎉', 'success');
      
      // Add to transaction history
      const newTx = {
        id: Date.now(),
        hash,
        type: isSwapping ? 'Swap' : isMinting ? 'Mint' : 'Approve',
        currency: selectedCurrency.code,
        amount: amount || 'N/A',
        timestamp: new Date().toLocaleString(),
        status: 'Confirmed'
      };
      setTransactions(prev => [newTx, ...prev.slice(0, 9)]); // Keep last 10
    }
  }, [hash, isConfirming, isConfirmed, isSwapping, isMinting, selectedCurrency.code, amount]);
  
  // Approve tokens
  const handleApprove = async () => {
    if (!amount || !isConnected) return;
    
    try {
      showNotification('Approving tokens...', 'pending');
      const amountWei = parseUnits(amount, selectedCurrency.decimals);
      await writeContract({
        address: selectedCurrency.address,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [CONTRACT_ADDRESSES.HOOK, amountWei]
      });
    } catch (error) {
      console.error('Approval failed:', error);
      showNotification(`Approval failed: ${error.shortMessage || error.message}`, 'error');
    }
  };
  
  // Swap tokens
  const handleSwap = async () => {
    if (!amount || !isConnected || isSwapping || !tokenBalance) return;
    
    // Check balance
    const amountWei = parseUnits(amount, selectedCurrency.decimals);
    if (tokenBalance < amountWei) {
      showNotification(`Insufficient balance. You have ${formatUnits(tokenBalance, selectedCurrency.decimals)} ${selectedCurrency.code}`, 'error');
      return;
    }
    
    setIsSwapping(true);
    try {
      showNotification('Executing swap...', 'pending');
      await writeContract({
        address: CONTRACT_ADDRESSES.HOOK,
        abi: HOOK_ABI,
        functionName: 'executeSwap',
        args: [
          selectedCurrency.address,
          CONTRACT_ADDRESSES.USDC,
          amountWei,
          true // isExactInput
        ]
      });
    } catch (error) {
      console.error('Swap failed:', error);
      
      // Check for circuit breaker error
      if (error.message && error.message.includes('circuit breaker')) {
        const officialRateFormatted = officialRateData ? 
          Number(formatUnits(officialRateData, 18)).toFixed(6) : 'N/A';
        const streetRateFormatted = streetRateData ? 
          Number(formatUnits(streetRateData, 18)).toFixed(6) : 'N/A';
        
        const deviation = streetRateData && officialRateData ? 
          Math.abs(((Number(streetRateData) - Number(officialRateData)) / Number(officialRateData)) * 100).toFixed(1) : 'N/A';
        
        showNotification(
          `🛑 Circuit Breaker Activated - ${deviation}% deviation exceeds 2% threshold. This demonstrates realistic forex risk management.`,
          'warning'
        );
      } else {
        showNotification(`Swap failed: ${error.shortMessage || error.message}`, 'error');
      }
    } finally {
      setIsSwapping(false);
    }
  };
  
  // Mint tokens
  const handleMint = async () => {
    if (!isConnected || !address || isMinting) return;
    
    setIsMinting(true);
    try {
      showNotification('Minting tokens...', 'pending');
      await writeContract({
        address: selectedCurrency.address,
        abi: ERC20_ABI,
        functionName: 'mint',
        args: [address, parseUnits('1000000', selectedCurrency.decimals)]
      });
    } catch (error) {
      console.error('Mint failed:', error);
      showNotification(`Mint failed: ${error.shortMessage || error.message}`, 'error');
    } finally {
      setIsMinting(false);
    }
  };
  
  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-blue-900 to-slate-900">
      {/* Notification */}
      {notification && (
        <div className={`fixed top-4 right-4 z-50 p-4 rounded-lg shadow-lg border transition-all duration-300 max-w-md ${
          notification.type === 'success' ? 'bg-green-900/90 border-green-500 text-green-100' :
          notification.type === 'error' ? 'bg-red-900/90 border-red-500 text-red-100' :
          notification.type === 'warning' ? 'bg-yellow-900/90 border-yellow-500 text-yellow-100' :
          'bg-blue-900/90 border-blue-500 text-blue-100'
        }`}>
          <div className="flex items-start justify-between">
            <div className="flex-1">
              <p className="text-sm font-medium">{notification.message}</p>
            </div>
            <button 
              onClick={() => setNotification(null)}
              className="ml-2 text-gray-400 hover:text-white"
            >
              ✕
            </button>
          </div>
        </div>
      )}
      
      <WalletConnection />
      
      <div className="container mx-auto px-4 py-8">
        {/* Header */}
        <div className="text-center mb-12">
          <h1 className="text-5xl font-bold mb-4 bg-gradient-to-r from-blue-400 via-purple-400 to-pink-400 bg-clip-text text-transparent">
            StreetRate Exchange
          </h1>
          <p className="text-xl text-slate-300 max-w-3xl mx-auto leading-relaxed">
            Experience real-world forex rates in DeFi. Our system integrates actual street exchange rates 
            from emerging markets with advanced circuit breaker protection.
          </p>
        </div>
        
        <div className="grid grid-cols-1 xl:grid-cols-3 gap-8 max-w-7xl mx-auto">
          {/* Main Swap Interface */}
          <div className="xl:col-span-2">
            <div className="bg-slate-800/50 backdrop-blur-xl border border-slate-700 rounded-3xl p-8 shadow-2xl">
              
              {/* Currency Selection */}
              <div className="mb-8">
                <label className="block text-sm font-semibold text-slate-300 mb-3">Select Currency</label>
                <select 
                  value={selectedCurrency.code}
                  onChange={(e) => {
                    const currency = CURRENCIES.find(c => c.code === e.target.value);
                    if (currency) setSelectedCurrency(currency);
                  }}
                  className="w-full bg-slate-700/50 border border-slate-600 rounded-xl p-4 text-white text-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                >
                  {CURRENCIES.map(currency => (
                    <option key={currency.code} value={currency.code}>
                      {currency.symbol} {currency.name} ({currency.code})
                    </option>
                  ))}
                </select>
              </div>
              
              {/* Mint Section */}
              <div className="mb-8 p-6 bg-gradient-to-r from-emerald-600/20 to-green-600/20 border border-emerald-500/30 rounded-2xl">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 bg-emerald-500 rounded-full flex items-center justify-center">
                    🪙
                  </div>
                  <div>
                    <h3 className="text-emerald-100 font-bold text-lg">Get Test Tokens</h3>
                    <p className="text-emerald-200 text-sm">Mint {selectedCurrency.code} tokens for testing</p>
                  </div>
                </div>
                <button
                  onClick={handleMint}
                  disabled={!isConnected || isMinting || isPending}
                  className="w-full py-3 bg-gradient-to-r from-emerald-500 to-green-500 hover:from-emerald-600 hover:to-green-600 disabled:from-gray-600 disabled:to-gray-600 rounded-xl text-white font-semibold text-lg transition-all duration-200 transform hover:scale-[1.02] disabled:scale-100"
                >
                  {!isConnected ? '🔗 Connect Wallet' :
                   isMinting || isPending ? '⏳ Minting...' : 
                   `💰 Mint 1,000,000 ${selectedCurrency.code}`}
                </button>
                <div className="mt-3 text-center text-emerald-200 text-sm">
                  <strong>Balance:</strong> {tokenBalance ? Number(formatUnits(tokenBalance, selectedCurrency.decimals)).toLocaleString() : '0'} {selectedCurrency.code}
                </div>
              </div>
              
              {/* Amount Input */}
              <div className="mb-8">
                <label className="block text-sm font-semibold text-slate-300 mb-3">Amount ({selectedCurrency.code})</label>
                <div className="relative">
                  <input
                    type="number"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    placeholder="Enter amount (e.g., 1000)"
                    className="w-full bg-slate-700/50 border border-slate-600 rounded-xl p-4 text-white text-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                  />
                  <div className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 font-medium">
                    {selectedCurrency.symbol}
                  </div>
                </div>
              </div>
              
              {/* Output Display */}
              {outputAmount && (
                <div className="mb-8 p-6 bg-gradient-to-r from-blue-600/20 to-purple-600/20 border border-blue-500/30 rounded-2xl">
                  <div className="text-center">
                    <div className="text-blue-200 text-sm font-medium mb-2">You will receive</div>
                    <div className="text-3xl font-bold text-blue-100">
                      {Number(outputAmount) < 0.001 ? 
                        Number(outputAmount).toFixed(8) : 
                        Number(outputAmount).toLocaleString(undefined, {minimumFractionDigits: 2, maximumFractionDigits: 6})
                      } USDC
                    </div>
                    <div className="text-blue-300 text-sm mt-2">
                      Rate: 1 {selectedCurrency.code} = {streetRateData ? 
                        (Number(formatUnits(streetRateData, 18)) < 0.001 ? 
                          Number(formatUnits(streetRateData, 18)).toFixed(8) : 
                          Number(formatUnits(streetRateData, 18)).toFixed(6)
                        ) : '...'} USDC
                    </div>
                  </div>
                </div>
              )}
              
              {/* Swap Buttons */}
              <div className="space-y-4">
                {needsApproval ? (
                  <button 
                    onClick={handleApprove}
                    disabled={!isConnected || !amount || isPending}
                    className="w-full py-4 bg-gradient-to-r from-orange-500 to-red-500 hover:from-orange-600 hover:to-red-600 disabled:from-gray-600 disabled:to-gray-600 rounded-xl text-white font-semibold text-lg transition-all duration-200 transform hover:scale-[1.02] disabled:scale-100"
                  >
                    {isPending ? '⏳ Approving...' : '🔓 Approve Tokens'}
                  </button>
                ) : (
                  <button 
                    onClick={handleSwap}
                    disabled={!isConnected || !amount || isSwapping || isPending || !tokenBalance || tokenBalance === 0n}
                    className="w-full py-4 bg-gradient-to-r from-blue-500 to-purple-500 hover:from-blue-600 hover:to-purple-600 disabled:from-gray-600 disabled:to-gray-600 rounded-xl text-white font-semibold text-lg transition-all duration-200 transform hover:scale-[1.02] disabled:scale-100"
                  >
                    {!isConnected ? '🔗 Connect Wallet' :
                     !tokenBalance || tokenBalance === 0n ? '🪙 Mint Tokens First' :
                     isSwapping || isPending ? '⏳ Swapping...' :
                     '🔄 Execute Swap'}
                  </button>
                )}
              </div>
            </div>
          </div>
          
          {/* Sidebar */}
          <div className="space-y-6">
            
            {/* Rate Information */}
            <div className="bg-slate-800/50 backdrop-blur-xl border border-slate-700 rounded-3xl p-6 shadow-2xl">
              <h3 className="text-xl font-bold text-white mb-6 flex items-center gap-2">
                📊 Exchange Rates
              </h3>
              
              <div className="space-y-4">
                <div className="flex justify-between items-center p-4 bg-slate-700/30 rounded-xl">
                  <span className="text-slate-300">Official Rate</span>
                  <span className="text-white font-mono">
                    {officialRateData ? 
                      (Number(formatUnits(officialRateData, 18)) < 0.001 ? 
                        Number(formatUnits(officialRateData, 18)).toFixed(8) : 
                        Number(formatUnits(officialRateData, 18)).toFixed(6)
                      ) : '...'} USDC
                  </span>
                </div>
                
                <div className="flex justify-between items-center p-4 bg-blue-900/30 rounded-xl border border-blue-500/30">
                  <span className="text-blue-200">Street Rate</span>
                  <span className="text-blue-100 font-mono">
                    {streetRateData ? 
                      (Number(formatUnits(streetRateData, 18)) < 0.001 ? 
                        Number(formatUnits(streetRateData, 18)).toFixed(8) : 
                        Number(formatUnits(streetRateData, 18)).toFixed(6)
                      ) : '...'} USDC
                  </span>
                </div>
                
                <div className="text-center text-sm text-slate-400 mt-4">
                  Street rates reflect real-world market conditions
                </div>
              </div>
            </div>
            
            {/* Transaction History */}
            <div className="bg-slate-800/50 backdrop-blur-xl border border-slate-700 rounded-3xl p-6 shadow-2xl">
              <h3 className="text-xl font-bold text-white mb-6 flex items-center gap-2">
                📋 Transaction History
              </h3>
              
              <div className="space-y-3 max-h-80 overflow-y-auto">
                {transactions.length > 0 ? (
                  transactions.map((tx) => (
                    <div key={tx.id} className="p-4 bg-slate-700/30 rounded-xl border border-slate-600/50">
                      <div className="flex justify-between items-start mb-2">
                        <div className="flex items-center gap-2">
                          <span className="text-sm font-medium text-white">{tx.type}</span>
                          <span className="text-xs bg-green-900/50 text-green-300 px-2 py-1 rounded-full">
                            {tx.status}
                          </span>
                        </div>
                        <span className="text-xs text-slate-400">{tx.timestamp}</span>
                      </div>
                      <div className="text-sm text-slate-300 mb-2">
                        {tx.amount} {tx.currency}
                      </div>
                      <div className="flex items-center gap-2">
                        <code className="text-xs font-mono text-blue-300 bg-slate-900/50 px-2 py-1 rounded flex-1 truncate">
                          {tx.hash}
                        </code>
                        <a 
                          href={`https://sepolia-blockscout.lisk.com/tx/${tx.hash}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-xs bg-blue-600 hover:bg-blue-700 px-3 py-1 rounded text-white transition-colors"
                        >
                          🔗
                        </a>
                      </div>
                    </div>
                  ))
                ) : (
                  <div className="text-center py-8 text-slate-400">
                    <p className="mb-2">📋 No transactions yet</p>
                    <p className="text-sm">Your transaction history will appear here</p>
                  </div>
                )}
              </div>
            </div>
            
            {/* Info Panel */}
            <div className="bg-slate-800/50 backdrop-blur-xl border border-slate-700 rounded-3xl p-6 shadow-2xl">
              <h3 className="text-lg font-bold text-white mb-4 flex items-center gap-2">
                ℹ️ How It Works
              </h3>
              <div className="space-y-3 text-sm text-slate-300">
                <div className="flex items-start gap-3">
                  <span className="text-blue-400 font-bold">1.</span>
                  <span>Connect your wallet to Lisk Sepolia testnet</span>
                </div>
                <div className="flex items-start gap-3">
                  <span className="text-blue-400 font-bold">2.</span>
                  <span>Mint test tokens using the green button</span>
                </div>
                <div className="flex items-start gap-3">
                  <span className="text-blue-400 font-bold">3.</span>
                  <span>Enter amount and approve if needed</span>
                </div>
                <div className="flex items-start gap-3">
                  <span className="text-blue-400 font-bold">4.</span>
                  <span>Execute swap to see street rates in action</span>
                </div>
                <div className="mt-4 p-3 bg-yellow-900/20 border border-yellow-500/30 rounded-lg">
                  <p className="text-yellow-200 text-xs">
                    ⚠️ Circuit breaker may activate due to realistic rate deviations (&gt;2%)
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}