import { useState, useEffect } from 'react';
import WalletConnection from './components/WalletConnection';
import { useAccount, useReadContract } from 'wagmi';
import { CONTRACT_ADDRESSES } from './config/sepolia';
import { parseUnits, formatUnits } from 'viem';

// Mock contract ABI for demonstration - replace with actual ABI in production
const ORACLE_ABI = [
  {
    "inputs": [{"name": "currency", "type": "bytes32"}],
    "name": "getOfficialRate",
    "outputs": [{"name": "rate", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"name": "currency", "type": "bytes32"}],
    "name": "getStreetRate",
    "outputs": [{"name": "rate", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  }
];

const HOOK_ABI = [
  {
    "inputs": [
      {"name": "currency", "type": "bytes32"},
      {"name": "amount", "type": "uint256"}
    ],
    "name": "getSwapOutput",
    "outputs": [{"name": "output", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  }
];

const CURRENCIES = [
  { code: 'NGN', name: 'Nigerian Naira', symbol: '₦' },
  { code: 'ARS', name: 'Argentine Peso', symbol: '$' },
  { code: 'GHS', name: 'Ghanaian Cedi', symbol: '₵' }
];



export default function App() {
  const { isConnected } = useAccount();
  const [selectedCurrency, setSelectedCurrency] = useState(CURRENCIES[0]);
  const [amount, setAmount] = useState('');
  const [outputAmount, setOutputAmount] = useState(null);
  
  // Get official rate from Chainlink oracle
  const { data: officialRateData, isLoading: isOfficialRateLoading } = useReadContract({
    address: CONTRACT_ADDRESSES.ORACLE,
    abi: ORACLE_ABI,
    functionName: 'getOfficialRate',
    args: [selectedCurrency.code],
    enabled: isConnected
  });
  
  // Get street rate from our oracle
  const { data: streetRateData, isLoading: isStreetRateLoading } = useReadContract({
    address: CONTRACT_ADDRESSES.ORACLE,
    abi: ORACLE_ABI,
    functionName: 'getStreetRate',
    args: [selectedCurrency.code],
    enabled: isConnected
  });
  
  // Calculate swap output
  useEffect(() => {
    if (amount && streetRateData && !isNaN(amount)) {
      const amountInWei = parseUnits(amount, 6); // Assuming USDC has 6 decimals
      const rate = streetRateData;
      const output = (BigInt(amountInWei) * BigInt(rate)) / BigInt(1e18);
      setOutputAmount(formatUnits(output, 6));
    } else {
      setOutputAmount(null);
    }
  }, [amount, streetRateData, selectedCurrency]);
  
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
              
              <div className="mb-6">
                <label className="block text-sm font-medium mb-2">Amount</label>
                <div className="relative">
                  <input
                    type="number"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    placeholder="0.00"
                    className="w-full bg-gray-800 border border-gray-700 rounded-lg p-3 text-web3-light focus:outline-none focus:ring-2 focus:ring-web3-purple"
                  />
                  <div className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400">
                    USDC
                  </div>
                </div>
              </div>
              
              <div className="space-y-4 mb-6">
                <div className="flex justify-between items-center p-4 bg-gray-800 rounded-lg">
                  <span className="text-gray-400">Official Rate</span>
                  <span className="font-medium">
                    {isOfficialRateLoading ? 'Loading...' : 
                      officialRateData ? 
                        `1 USDC = ${formatUnits(officialRateData, 18)} ${selectedCurrency.symbol}` : 
                        'N/A'}
                  </span>
                </div>
                
                <div className="flex justify-between items-center p-4 bg-gray-800 rounded-lg">
                  <span className="text-gray-400">Street Rate</span>
                  <span className="font-medium text-web3-purple">
                    {isStreetRateLoading ? 'Loading...' : 
                      streetRateData ? 
                        `1 USDC = ${formatUnits(streetRateData, 18)} ${selectedCurrency.symbol}` : 
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
              
              <button 
                disabled={!isConnected || !amount || !streetRateData}
                className={`w-full py-3 rounded-lg font-medium text-lg transition-all ${
                  !isConnected || !amount || !streetRateData
                    ? 'bg-gray-700 cursor-not-allowed'
                    : 'bg-web3-purple hover:bg-purple-600'
                }`}
              >
                {isConnected ? 'Swap' : 'Connect Wallet to Swap'}
              </button>
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
                        `${formatUnits(officialRateData, 18)} ${selectedCurrency.symbol}` : 
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
                        `${formatUnits(streetRateData, 18)} ${selectedCurrency.symbol}` : 
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
