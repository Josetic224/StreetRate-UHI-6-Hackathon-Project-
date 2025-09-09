// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/HybridRateOracle.sol";
import "../src/StreetRateHookStandalone.sol";
import "../src/tokens/FiatTokens.sol";

contract DeployHybridSystem is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        
        if (deployerPrivateKey == 0) {
            // Use default test key for local testing
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        }
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("\n=== Deploying Multi-Currency Street Rate System ===\n");
        
        // Step 1: Deploy fiat tokens
        console.log("Step 1: Deploying fiat tokens...");
        NGNToken ngn = new NGNToken();
        console.log("  NGN Token deployed at:", address(ngn));
        
        ARSToken ars = new ARSToken();
        console.log("  ARS Token deployed at:", address(ars));
        
        GHSToken ghs = new GHSToken();
        console.log("  GHS Token deployed at:", address(ghs));
        
        USDCMock usdc = new USDCMock();
        console.log("  USDC Token deployed at:", address(usdc));
        
        // Step 2: Deploy HybridRateOracle
        console.log("\nStep 2: Deploying HybridRateOracle...");
        HybridRateOracle oracle = new HybridRateOracle();
        console.log("  Oracle deployed at:", address(oracle));
        
        // Step 3: Initialize oracle with rates
        console.log("\nStep 3: Initializing exchange rates...");
        oracle.initializeDefaultRates(
            address(ngn),
            address(ars),
            address(ghs),
            address(usdc)
        );
        console.log("  Rates initialized for NGN, ARS, and GHS");
        
        // Step 4: Deploy StreetRateHook
        console.log("\nStep 4: Deploying StreetRateHook...");
        uint256 deviationThreshold = 5000; // 50% threshold for demo
        StreetRateHookStandalone hook = new StreetRateHookStandalone(oracle, deviationThreshold);
        console.log("  Hook deployed at:", address(hook));
        console.log("  Deviation threshold:", deviationThreshold / 100, "%");
        
        vm.stopBroadcast();
        
        // Print summary
        printDeploymentSummary(
            address(ngn),
            address(ars),
            address(ghs),
            address(usdc),
            address(oracle),
            address(hook)
        );
        
        // Print rate information
        printRateInformation(oracle, address(ngn), address(ars), address(ghs), address(usdc));
    }
    
    function printDeploymentSummary(
        address ngn,
        address ars,
        address ghs,
        address usdc,
        address oracle,
        address hook
    ) internal view {
        console.log("\n=========================================================");
        console.log("       DEPLOYMENT SUMMARY - STREET RATE SYSTEM");
        console.log("=========================================================");
        console.log("TOKENS:");
        console.log("  NGN Token:    ", ngn);
        console.log("  ARS Token:    ", ars);
        console.log("  GHS Token:    ", ghs);
        console.log("  USDC Token:   ", usdc);
        console.log("");
        console.log("CONTRACTS:");
        console.log("  Oracle:       ", oracle);
        console.log("  Hook:         ", hook);
        console.log("=========================================================");
    }
    
    function printRateInformation(
        HybridRateOracle oracle,
        address ngn,
        address ars,
        address ghs,
        address usdc
    ) internal view {
        console.log("\n=========================================================");
        console.log("           EXCHANGE RATE CONFIGURATION");
        console.log("=========================================================");
        
        // NGN rates
        uint256 ngnOfficial = oracle.getOfficialRate(ngn, usdc);
        uint256 ngnStreet = oracle.getStreetRate(ngn, usdc);
        uint256 ngnDeviation = oracle.getDeviation(ngn, usdc);
        
        console.log("NGN/USDC:");
        console.log("  Official: 1 NGN = 0.00125 USDC (800 NGN/USD)");
        console.log("  Street:   1 NGN = 0.000667 USDC (1500 NGN/USD)");
        console.log("  Deviation:", ngnDeviation / 100, "%");
        
        // ARS rates
        uint256 arsOfficial = oracle.getOfficialRate(ars, usdc);
        uint256 arsStreet = oracle.getStreetRate(ars, usdc);
        uint256 arsDeviation = oracle.getDeviation(ars, usdc);
        
        console.log("");
        console.log("ARS/USDC:");
        console.log("  Official: 1 ARS = 0.00286 USDC (350 ARS/USD)");
        console.log("  Street:   1 ARS = 0.001 USDC (1000 ARS/USD)");
        console.log("  Deviation:", arsDeviation / 100, "%");
        
        // GHS rates
        uint256 ghsOfficial = oracle.getOfficialRate(ghs, usdc);
        uint256 ghsStreet = oracle.getStreetRate(ghs, usdc);
        uint256 ghsDeviation = oracle.getDeviation(ghs, usdc);
        
        console.log("");
        console.log("GHS/USDC:");
        console.log("  Official: 1 GHS = 0.0833 USDC (12 GHS/USD)");
        console.log("  Street:   1 GHS = 0.0667 USDC (15 GHS/USD)");
        console.log("  Deviation:", ghsDeviation / 100, "%");
        console.log("=========================================================");
        
        console.log("\nNote: The hook will apply street rates for all swaps");
        console.log("and revert if deviation exceeds the configured threshold.");
    }
}

/// @notice Script to mint tokens to test addresses
contract MintTestTokens is Script {
    function run(
        address ngnAddress,
        address arsAddress,
        address ghsAddress,
        address usdcAddress,
        address recipient
    ) external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        
        if (deployerPrivateKey == 0) {
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        }
        
        vm.startBroadcast(deployerPrivateKey);
        
        NGNToken(ngnAddress).mint(recipient, 1000000e18);
        console.log("Minted 1,000,000 NGN to", recipient);
        
        ARSToken(arsAddress).mint(recipient, 1000000e18);
        console.log("Minted 1,000,000 ARS to", recipient);
        
        GHSToken(ghsAddress).mint(recipient, 10000e18);
        console.log("Minted 10,000 GHS to", recipient);
        
        USDCMock(usdcAddress).mint(recipient, 10000e6);
        console.log("Minted 10,000 USDC to", recipient);
        
        vm.stopBroadcast();
    }
}
