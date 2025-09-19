import { useState, useEffect } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits } from 'viem';
import WalletConnection from './components/WalletConnection';
import { CONTRACT_ADDRESSES } from './config/sepolia';

const CURRENCIES = [
  { code: 'NGN', name: 'Nigerian Naira', symbol: '₦' },
  { code: 'ARS', name: 'Argentine Peso', symbol: '$' },
  { code: 'GHS', name: 'Ghanaian Cedi', symbol: '₵' }
];

// Simple swap ABI for demonstration
const SWAP_ABI = [
  {
    "inputs": [
      {"name": "currency", "type": "bytes32"},
      {"name": "amountIn", "type": "uint256"}
    ],
    "name": "swap",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
];

export default function AppFixed() {
  const { isConnected, address } = useAccount();
  const [selectedCurrency, setSelectedCurrency] = useState(CURRENCIES[0]);
  const [amount, setAmount] = useState('');
  const [isSwapping, setIsSwapping] = useState(false);
  const [txStatus, setTxStatus] = useState('');
  const [transactions, setTransactions] = useState([]);
  
  const { writeContract, data: hash } = useWriteContract();
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash,
  });
  
  const handleSwap = async () => {
    if (!amount || parseFloat(amount) <= 0) {
      setTxStatus('Please enter a valid amount');
      setTimeout(() => setTxStatus(''), 3000);
      return;
    }
    
    try {
      setIsSwapping(true);
      setTxStatus('Initiating real swap on Sepolia...');
      
      if (CONTRACT_ADDRESSES.HOOK) {
        setTxStatus('Please confirm transaction in your wallet...');
        
        // REAL CONTRACT INTERACTION
        // Convert currency code to bytes32
        const currencyBytes32 = '0x' + selectedCurrency.code.padEnd(64, '0');
        
        writeContract({
          address: CONTRACT_ADDRESSES.HOOK,
          abi: SWAP_ABI,
          functionName: 'swap',
          args: [currencyBytes32, parseUnits(amount, 6)], // USDC has 6 decimals
        });
        
        // The transaction will be handled by the useWaitForTransactionReceipt hook
      } else {
        setTxStatus('❌ Contract address not configured');
        setIsSwapping(false);
      }
    } catch (error) {
      console.error('Swap error:', error);
      setTxStatus('❌ Swap failed: ' + error.message);
      setIsSwapping(false);
      setTimeout(() => setTxStatus(''), 5000);
    }
  };
  
  // Handle transaction confirmation
  useEffect(() => {
    if (hash) {
      setTxStatus(`Transaction submitted! Hash: ${hash.slice(0, 10)}...`);
      console.log('Transaction hash:', hash);
    }
    
    if (isConfirming) {
      setTxStatus('⏳ Waiting for confirmation...');
    }
    
    if (isConfirmed) {
      setTxStatus('✅ Swap confirmed on blockchain!');
      
      // Add to transaction history with REAL hash
      const newTx = {
        id: Date.now(),
        hash: hash,
        currency: selectedCurrency.code,
        amountIn: amount,
        amountOut: (parseFloat(amount) * (selectedCurrency.code === 'NGN' ? 1500 : selectedCurrency.code === 'ARS' ? 1000 : 15)).toFixed(2),
        symbol: selectedCurrency.symbol,
        timestamp: new Date().toLocaleTimeString(),
        status: 'confirmed'
      };
      setTransactions(prev => [newTx, ...prev].slice(0, 5));
      
      setAmount('');
      setIsSwapping(false);
      setTimeout(() => setTxStatus(''), 5000);
    }
  }, [hash, isConfirming, isConfirmed, amount, selectedCurrency]);
  
  return (
    <div className="min-h-screen bg-gray-900 text-white">
      <WalletConnection />
      
      <main className="container mx-auto px-4 py-8">
        <div className="text-center mb-12">
          <h1 className="text-4xl font-bold mb-4 bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">
            StreetRate Swap
          </h1>
          <p className="text-xl text-gray-400 max-w-2xl mx-auto">
            Experience the power of decentralized finance with real-world exchange rates
          </p>
        </div>
        
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Swap Interface */}
          <div className="lg:col-span-2">
            <div className="bg-gray-800 border border-gray-700 rounded-2xl p-6 shadow-xl">
              <div className="mb-6">
                <label className="block text-sm font-medium mb-2">Currency</label>
                <select 
                  value={selectedCurrency.code}
                  onChange={(e) => {
                    const currency = CURRENCIES.find(c => c.code === e.target.value);
                    setSelectedCurrency(currency);
                  }}
                  className="w-full bg-gray-700 border border-gray-600 rounded-lg p-3 text-white focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
                  {CURRENCIES.map(currency => (
                    <option key={currency.code} value={currency.code}>
                      {currency.name} ({currency.code})
                    </option>
                  ))}
                </select>
              </div>
              
              <div className="mb-6">
                <label className="block text-sm font-medium mb-2">Amount (USDC)</label>
                <input 
                  type="number" 
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  placeholder="Enter amount..."
                  className="w-full bg-gray-700 border border-gray-600 rounded-lg p-3 text-white focus:outline-none focus:ring-2 focus:ring-purple-500"
                />
              </div>
              
              <div className="mb-6">
                <label className="block text-sm font-medium mb-2">You will receive</label>
                <div className="bg-gray-700 rounded-lg p-3">
                  <span className="text-xl">
                    {amount ? `~${(parseFloat(amount) * (selectedCurrency.code === 'NGN' ? 1500 : selectedCurrency.code === 'ARS' ? 1000 : 15)).toFixed(2)} ${selectedCurrency.symbol}` : '0.00'}
                  </span>
                </div>
              </div>
              
              <button 
                onClick={handleSwap}
                className={`w-full py-3 rounded-lg font-medium transition-colors ${
                  isConnected && !isSwapping
                    ? 'bg-purple-600 hover:bg-purple-700 text-white' 
                    : 'bg-gray-600 text-gray-400 cursor-not-allowed'
                }`}
                disabled={!isConnected || isSwapping || !amount}
              >
                {!isConnected ? 'Connect Wallet to Swap' : 
                 isSwapping ? 'Processing...' : 
                 'Swap'}
              </button>
              
              {txStatus && (
                <div className={`mt-4 p-3 rounded-lg text-center ${
                  txStatus.includes('✅') ? 'bg-green-900 text-green-300' :
                  txStatus.includes('❌') ? 'bg-red-900 text-red-300' :
                  'bg-blue-900 text-blue-300'
                }`}>
                  {txStatus}
                </div>
              )}
            </div>
          </div>
          
          {/* Rate Information */}
          <div>
            <div className="bg-gray-800 border border-gray-700 rounded-2xl p-6 shadow-xl">
              <h2 className="text-xl font-bold mb-4">Exchange Rates</h2>
              
              <div className="space-y-4">
                <div>
                  <div className="flex justify-between mb-1">
                    <span className="text-gray-400">Official Rate</span>
                    <span className="text-gray-500">
                      {isConnected ? 
                        (selectedCurrency.code === 'NGN' ? '800 ₦/USD' : 
                         selectedCurrency.code === 'ARS' ? '950 ARS/USD' : 
                         '14.5 GHS/USD') : 'Connect wallet'}
                    </span>
                  </div>
                  <div className="h-2 bg-gray-700 rounded-full overflow-hidden">
                    <div className="h-full bg-gray-500" style={{ width: selectedCurrency.code === 'NGN' ? '53%' : '95%' }}></div>
                  </div>
                </div>
                
                <div>
                  <div className="flex justify-between mb-1">
                    <span className="text-gray-400">Street Rate</span>
                    <span className="text-purple-400">
                      {isConnected ? 
                        (selectedCurrency.code === 'NGN' ? '1,500 ₦/USD' : 
                         selectedCurrency.code === 'ARS' ? '1,000 ARS/USD' : 
                         '15 GHS/USD') : 'Connect wallet'}
                    </span>
                  </div>
                  <div className="h-2 bg-gray-700 rounded-full overflow-hidden">
                    <div className="h-full bg-purple-500 w-full"></div>
                  </div>
                </div>
              </div>
              
              <div className="mt-6 p-3 bg-gray-700 rounded-lg">
                <p className="text-sm text-gray-400">Rate Difference</p>
                <p className="text-lg font-bold text-green-400">
                  {selectedCurrency.code === 'NGN' ? '+87.5%' : 
                   selectedCurrency.code === 'ARS' ? '+5.26%' : 
                   '+3.45%'}
                </p>
              </div>
            </div>
          </div>
        </div>
        
        {/* Transaction History / Proof */}
        <div className="mt-12">
          <div className="bg-gray-800 border border-gray-700 rounded-2xl p-6 shadow-xl">
            <h2 className="text-xl font-bold mb-4">Transaction History & Proof</h2>
            
            {transactions.length > 0 ? (
              <div className="space-y-3">
                {transactions.map(tx => (
                  <div key={tx.id} className="p-4 bg-gray-700 rounded-lg">
                    <div className="flex justify-between items-start mb-2">
                      <div>
                        <p className="font-medium">Swapped {tx.amountIn} USDC → {tx.amountOut} {tx.currency}</p>
                        <p className="text-sm text-gray-400">{tx.timestamp}</p>
                      </div>
                      <span className="text-green-400 text-sm">✓ Confirmed</span>
                    </div>
                    <div className="mt-2">
                      <p className="text-xs text-gray-400 mb-1">Transaction Hash:</p>
                      <div className="flex items-center gap-2">
                        <code className="text-xs text-purple-400 bg-gray-900 px-2 py-1 rounded">
                          {tx.hash.slice(0, 20)}...{tx.hash.slice(-18)}
                        </code>
                        <a 
                          href={`https://sepolia.etherscan.io/tx/${tx.hash}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-xs bg-purple-600 hover:bg-purple-700 px-3 py-1 rounded text-white transition-colors"
                        >
                          View Proof on Etherscan →
                        </a>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-center py-8 text-gray-500">
                <p>No transactions yet</p>
                <p className="text-sm mt-2">Complete a swap to see transaction proof here</p>
              </div>
            )}
            
            {transactions.length > 0 && (
              <div className="mt-4 p-3 bg-blue-900/30 border border-blue-700 rounded-lg">
                <p className="text-sm text-blue-300">
                  <strong>💡 Proof of Transaction:</strong> Click "View Proof on Etherscan" to see the immutable blockchain record of your swap. 
                  This includes the transaction details, gas fees, block confirmation, and smart contract interaction.
                </p>
              </div>
            )}
          </div>
        </div>
        
        {/* Status */}
        <div className="mt-8 text-center">
          {isConnected ? (
            <p className="text-green-400">✓ Wallet Connected: {address?.slice(0, 6)}...{address?.slice(-4)}</p>
          ) : (
            <p className="text-yellow-400">⚠ Please connect your wallet to start swapping</p>
          )}
        </div>
      </main>
    </div>
  );
}
