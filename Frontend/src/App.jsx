import { useState, useEffect } from 'react';
import WalletConnection from './components/WalletConnection';
import { useAccount, useReadContract, useWriteContract } from 'wagmi';
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
  
  const { writeContract, isPending } = useWriteContract();
  
  // Get token balance
  const { data: tokenBalance } = useReadContract({
    address: selectedCurrency.address,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [address],
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
  
  // Mint tokens
  const handleMint = async () => {
    if (!isConnected || !address || isMinting) return;
    
    setIsMinting(true);
    try {
      await writeContract({
        address: selectedCurrency.address,
        abi: ERC20_ABI,
        functionName: 'mint',
        args: [address, parseUnits('1000000', selectedCurrency.decimals)]
      });
    } catch (error) {
      console.error('Mint failed:', error);
      alert(`Mint failed: ${error.shortMessage || error.message}`);
    } finally {
      setIsMinting(false);
    }
  };
  
  return (
    <div className="min-h-screen bg-gray-900 text-white p-8">
      <WalletConnection />
      
      <div className="max-w-2xl mx-auto mt-8">
        <h1 className="text-3xl font-bold text-center mb-8">StreetRate Swap</h1>
        
        {/* Currency Selection */}
        <div className="mb-6">
          <label className="block text-sm font-medium mb-2">Select Currency</label>
          <select 
            value={selectedCurrency.code}
            onChange={(e) => {
              const currency = CURRENCIES.find(c => c.code === e.target.value);
              if (currency) setSelectedCurrency(currency);
            }}
            className="w-full bg-gray-800 border border-gray-700 rounded-lg p-3"
          >
            {CURRENCIES.map(currency => (
              <option key={currency.code} value={currency.code}>
                {currency.name} ({currency.code})
              </option>
            ))}
          </select>
        </div>
        
        {/* MINT SECTION - ALWAYS VISIBLE - SUPER BRIGHT */}
        <div className="mb-6 p-8 bg-green-600 border-4 border-yellow-400 rounded-xl shadow-2xl">
          <h3 className="text-white font-black text-2xl mb-4 text-center">🪙 GET TEST TOKENS HERE 🪙</h3>
          <p className="text-white text-center mb-6 text-lg">
            CLICK THE BUTTON BELOW TO MINT {selectedCurrency.code} TOKENS!
          </p>
          <button
            onClick={handleMint}
            disabled={!isConnected || isMinting || isPending}
            className="w-full py-6 bg-yellow-500 hover:bg-yellow-400 disabled:bg-gray-500 rounded-xl font-black text-black text-xl border-4 border-black shadow-lg"
          >
            {!isConnected ? '🔗 CONNECT WALLET FIRST!' :
             isMinting || isPending ? '⏳ MINTING TOKENS...' : 
             `💰 MINT 1,000,000 ${selectedCurrency.code} TOKENS NOW!`}
          </button>
          <div className="mt-4 text-center text-white bg-green-800 p-4 rounded-lg text-lg">
            <strong>Your Balance:</strong> {tokenBalance ? formatUnits(tokenBalance, selectedCurrency.decimals) : '0'} {selectedCurrency.code}
          </div>
        </div>
        
        {/* Amount Input */}
        <div className="mb-6">
          <label className="block text-sm font-medium mb-2">Amount ({selectedCurrency.code})</label>
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="Enter amount (e.g., 1000)"
            className="w-full bg-gray-800 border border-gray-700 rounded-lg p-3 text-lg"
          />
        </div>
        
        {/* Output Display */}
        {outputAmount && (
          <div className="mb-6 p-4 bg-blue-900/30 border border-blue-500 rounded-lg">
            <div className="text-center">
              <span className="text-blue-300">You will receive:</span>
              <div className="text-3xl font-bold text-blue-400 mt-2">
                {Number(outputAmount).toFixed(6)} USDC
              </div>
            </div>
          </div>
        )}
        
        {/* Rate Display */}
        <div className="mb-6 p-4 bg-gray-800 border border-gray-700 rounded-lg">
          <h3 className="font-medium mb-2">📊 Current Street Rate</h3>
          <div className="text-lg">
            1 {selectedCurrency.code} = {streetRateData ? 
              Number(formatUnits(streetRateData, 18)).toFixed(6) : '...'} USDC
          </div>
        </div>
        
        {/* Example Calculation */}
        <div className="mb-6 p-4 bg-yellow-600 border border-yellow-400 rounded-lg">
          <h3 className="text-yellow-100 font-medium mb-2">💫 YELLOW SECTION - DEBUG</h3>
          <div className="text-sm text-yellow-200">
            If you enter <strong>1000 {selectedCurrency.code}</strong>, you'll get approximately{' '}
            <strong>
              {streetRateData ? 
                (1000 * Number(formatUnits(streetRateData, 18))).toFixed(3) : '...'
              } USDC
            </strong>
          </div>
        </div>
        
        {/* YELLOW SWAP BUTTON FOR DEBUG */}
        <div className="mb-6">
          <button className="w-full py-4 bg-yellow-500 hover:bg-yellow-400 text-black font-black text-xl rounded-lg border-4 border-black">
            🟡 YELLOW SWAP BUTTON - DEBUG 🟡
          </button>
        </div>
        
        {/* Debug Info */}
        <div className="mb-6 p-4 bg-red-900/20 border border-red-500 rounded-lg">
          <h3 className="text-red-300 font-medium mb-2">🔍 Debug Info</h3>
          <div className="text-xs space-y-1 text-red-200">
            <div><strong>Connected:</strong> {isConnected ? 'Yes' : 'No'}</div>
            <div><strong>Address:</strong> {address || 'Not connected'}</div>
            <div><strong>Selected:</strong> {selectedCurrency.code}</div>
            <div><strong>Token Address:</strong> {selectedCurrency.address}</div>
            <div><strong>Amount Input:</strong> {amount || 'None'}</div>
            <div><strong>Street Rate (raw):</strong> {streetRateData?.toString() || 'Loading...'}</div>
            <div><strong>Calculated Output:</strong> {outputAmount || 'N/A'}</div>
            <div><strong>Token Balance:</strong> {tokenBalance ? formatUnits(tokenBalance, 18) : '0'}</div>
          </div>
        </div>
      </div>
    </div>
  );
}