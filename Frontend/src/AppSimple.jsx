import { useAccount } from 'wagmi';
import WalletConnection from './components/WalletConnection';

export default function AppSimple() {
  const { isConnected, address } = useAccount();
  
  return (
    <div className="min-h-screen bg-gray-900 text-white">
      <WalletConnection />
      
      <main className="container mx-auto px-4 py-8">
        <div className="text-center mb-12">
          <h1 className="text-4xl font-bold mb-4">
            StreetRate Swap - Debug Mode
          </h1>
          <p className="text-xl text-gray-400">
            Testing if the app renders
          </p>
          {isConnected ? (
            <p className="mt-4 text-green-400">Wallet Connected: {address}</p>
          ) : (
            <p className="mt-4 text-yellow-400">Please connect your wallet</p>
          )}
        </div>
        
        <div className="bg-gray-800 rounded-lg p-6">
          <h2 className="text-2xl mb-4">Debug Info</h2>
          <ul className="space-y-2">
            <li>React: Working ✓</li>
            <li>Tailwind: {typeof window !== 'undefined' ? 'Loaded ✓' : 'Loading...'}</li>
            <li>Wagmi: {isConnected !== undefined ? 'Initialized ✓' : 'Loading...'}</li>
          </ul>
        </div>
      </main>
    </div>
  );
}
