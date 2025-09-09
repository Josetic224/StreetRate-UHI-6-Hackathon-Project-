// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/StreetRateHookStandalone.sol";
import "../src/MockStreetRateOracle.sol";

contract DeployStreetRateHook is Script {
    function run() external {
        // Get deployment private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy oracle
        MockStreetRateOracle oracle = new MockStreetRateOracle();
        console.log("Oracle deployed at:", address(oracle));
        
        // Deploy hook with 2% deviation threshold
        StreetRateHookStandalone hook = new StreetRateHookStandalone(
            oracle,
            200 // 2% threshold
        );
        console.log("Hook deployed at:", address(hook));
        
        // Set up some default rates for demo
        // NGN/USDC rates
        address ngn = address(0x1111); // Mock NGN address
        address usdc = address(0x2222); // Mock USDC address
        
        oracle.setRates(
            ngn,
            usdc,
            625000000000000,   // Official: 1 NGN = 0.000625 USDC (1600 NGN/USD)
            606060606060606    // Street: 1 NGN = 0.000606 USDC (1650 NGN/USD)
        );
        console.log("Set NGN/USDC rates");
        
        // GHS/USDC rates
        address ghs = address(0x3333); // Mock GHS address
        
        oracle.setRates(
            ghs,
            usdc,
            85000000000000000,  // Official: 1 GHS = 0.085 USDC (11.76 GHS/USD)
            83000000000000000   // Street: 1 GHS = 0.083 USDC (12.05 GHS/USD)
        );
        console.log("Set GHS/USDC rates");
        
        vm.stopBroadcast();
        
        // Print deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("Oracle Address:", address(oracle));
        console.log("Hook Address:", address(hook));
        console.log("Deviation Threshold:", hook.deviationThreshold(), "basis points");
        console.log("\n=== Configured Pairs ===");
        console.log("NGN/USDC - Official: 0.000625, Street: 0.000606");
        console.log("GHS/USDC - Official: 0.085, Street: 0.083");
    }
}
