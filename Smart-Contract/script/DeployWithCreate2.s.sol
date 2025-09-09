// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/HookDeployer.sol";
import "../src/HybridRateOracle.sol";
import "../src/tokens/FiatTokens.sol";

contract DeployWithCreate2 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        
        if (deployerPrivateKey == 0) {
            // Use default test key for local testing
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        }
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("\n=== Deploying Street Rate System with CREATE2 ===\n");
        
        // Step 1: Deploy fiat tokens
        console.log("Step 1: Deploying fiat tokens...");
        NGNToken ngn = new NGNToken();
        ARSToken ars = new ARSToken();
        GHSToken ghs = new GHSToken();
        USDCMock usdc = new USDCMock();
        
        console.log("  NGN:", address(ngn));
        console.log("  ARS:", address(ars));
        console.log("  GHS:", address(ghs));
        console.log("  USDC:", address(usdc));
        
        // Step 2: Deploy oracle
        console.log("\nStep 2: Deploying HybridRateOracle...");
        HybridRateOracle oracle = new HybridRateOracle();
        console.log("  Oracle:", address(oracle));
        
        // Initialize rates
        oracle.initializeDefaultRates(
            address(ngn),
            address(ars),
            address(ghs),
            address(usdc)
        );
        console.log("  Rates initialized");
        
        // Step 3: Deploy HookDeployer
        console.log("\nStep 3: Deploying HookDeployer...");
        HookDeployer deployer = new HookDeployer();
        console.log("  Deployer:", address(deployer));
        
        // Step 4: Find a suitable salt for CREATE2
        console.log("\nStep 4: Finding suitable salt for CREATE2...");
        uint256 deviationThreshold = 7000; // 70% for demo
        
        (bytes32 salt, address expectedHookAddress) = deployer.findSalt(
            oracle,
            deviationThreshold,
            10000 // max iterations
        );
        
        console.log("  Found salt:", uint256(salt));
        console.log("  Expected hook address:", expectedHookAddress);
        
        // Verify the address has correct flags
        uint256 flags = deployer.getFlags(expectedHookAddress);
        console.log("  Address flags:", flags);
        console.log("  Has beforeSwap flag:", (flags & 0x80) == 0x80);
        
        // Step 5: Deploy the hook with CREATE2
        console.log("\nStep 5: Deploying StreetRateHook with CREATE2...");
        StreetRateHookStandalone hook = deployer.deployHook(salt, oracle, deviationThreshold);
        console.log("  Hook deployed at:", address(hook));
        
        // Verify deployment
        require(address(hook) == expectedHookAddress, "Hook address mismatch");
        console.log("  [SUCCESS] Hook deployed at expected address!");
        
        vm.stopBroadcast();
        
        // Print summary
        printSummary(
            address(ngn),
            address(ars),
            address(ghs),
            address(usdc),
            address(oracle),
            address(hook),
            address(deployer),
            salt
        );
    }
    
    function printSummary(
        address ngn,
        address ars,
        address ghs,
        address usdc,
        address oracle,
        address hook,
        address deployer,
        bytes32 salt
    ) internal view {
        console.log("\n=========================================================");
        console.log("         CREATE2 DEPLOYMENT SUMMARY");
        console.log("=========================================================");
        console.log("TOKENS:");
        console.log("  NGN:      ", ngn);
        console.log("  ARS:      ", ars);
        console.log("  GHS:      ", ghs);
        console.log("  USDC:     ", usdc);
        console.log("");
        console.log("INFRASTRUCTURE:");
        console.log("  Oracle:   ", oracle);
        console.log("  Deployer: ", deployer);
        console.log("");
        console.log("HOOK (CREATE2):");
        console.log("  Address:  ", hook);
        console.log("  Salt:     ", uint256(salt));
        
        // Show the last 2 bytes of the hook address (where flags are)
        uint256 addressBits = uint256(uint160(hook));
        uint256 lastTwoBytes = addressBits & 0xFFFF;
        console.log("  Flags:     0x", toHexString(lastTwoBytes));
        
        console.log("=========================================================");
        console.log("\nThe hook address has the correct flags for beforeSwap!");
        console.log("This allows it to intercept and modify swap execution.");
    }
    
    function toHexString(uint256 value) internal pure returns (string memory) {
        bytes memory buffer = new bytes(4);
        for (uint256 i = 0; i < 4; i++) {
            uint8 digit = uint8(value >> (4 * (3 - i))) & 0xF;
            if (digit < 10) {
                buffer[i] = bytes1(uint8(48 + digit));
            } else {
                buffer[i] = bytes1(uint8(87 + digit));
            }
        }
        return string(buffer);
    }
}

/// @notice Script to just find a valid salt without deploying
contract FindSaltOnly is Script {
    function run() external view {
        // Deploy a temporary oracle for calculation
        address oracleAddress = address(0x1234567890123456789012345678901234567890);
        uint256 deviationThreshold = 7000;
        
        // This would need the deployer address to be accurate
        address deployerAddress = address(0x1234567890123456789012345678901234567890);
        
        console.log("\nSearching for valid CREATE2 salt...");
        console.log("Oracle:", oracleAddress);
        console.log("Deployer:", deployerAddress);
        console.log("Threshold:", deviationThreshold);
        
        // Manual search for demonstration
        bytes memory bytecode = type(StreetRateHookStandalone).creationCode;
        bytes memory constructorArgs = abi.encode(IStreetRateOracle(oracleAddress), deviationThreshold);
        bytes32 initCodeHash = keccak256(abi.encodePacked(bytecode, constructorArgs));
        
        for (uint256 i = 0; i < 10000; i++) {
            bytes32 salt = bytes32(i);
            
            bytes32 hash = keccak256(
                abi.encodePacked(
                    bytes1(0xff),
                    deployerAddress,
                    salt,
                    initCodeHash
                )
            );
            
            address hookAddress = address(uint160(uint256(hash)));
            uint256 addressBits = uint256(uint160(hookAddress));
            uint256 lastTwoBytes = addressBits & 0xFFFF;
            
            if ((lastTwoBytes & 0x80) == 0x80) {
                console.log("\nFound valid salt!");
                console.log("  Salt:", i);
                console.log("  Address:", hookAddress);
                console.log("  Flags: 0x", toHexString(lastTwoBytes));
                break;
            }
        }
    }
    
    function toHexString(uint256 value) internal pure returns (string memory) {
        bytes memory buffer = new bytes(4);
        for (uint256 i = 0; i < 4; i++) {
            uint8 digit = uint8(value >> (4 * (3 - i))) & 0xF;
            if (digit < 10) {
                buffer[i] = bytes1(uint8(48 + digit));
            } else {
                buffer[i] = bytes1(uint8(87 + digit));
            }
        }
        return string(buffer);
    }
}
