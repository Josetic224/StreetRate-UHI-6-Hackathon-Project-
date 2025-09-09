// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {IPoolManager} from "../lib/v4-core/src/interfaces/IPoolManager.sol";
import {IStreetRateOracle} from "../src/interfaces/IStreetRateOracle.sol";
import "../src/StreetRateHookV4Simple.sol";

contract DeployHookOnly is Script {
    // Already deployed addresses
    address constant ORACLE = 0xd35fCdCeC137756A3F6da6d75beF82506E90A1cE;
    address constant POOL_MANAGER = 0x2FfB75fbf5707848CDdd942921D76933c7BBd90C;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("\n=== Deploying Hook Only ===");
        console.log("Deployer:", deployer);
        console.log("Oracle:", ORACLE);
        console.log("PoolManager:", POOL_MANAGER);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy a dummy contract first to increment nonce
        new DummyContract();
        
        // Now deploy the actual hook
        StreetRateHookV4Simple hook = new StreetRateHookV4Simple(
            IPoolManager(POOL_MANAGER),
            IStreetRateOracle(ORACLE),
            7000 // 70% deviation threshold
        );
        
        address hookAddress = address(hook);
        console.log("\nHook deployed at:", hookAddress);
        
        // Check address flags
        uint256 flags = uint256(uint160(hookAddress)) & 0xFFFF;
        console.log("Address flags (hex):", flags);
        console.log("Has beforeSwap flag (0x80)?", (flags & 0x80) != 0);
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployed Contracts Summary ===");
        console.log("NGN:         0x9ac0ec34c027A77a9aeB46Ee9167ceed4CC5734D");
        console.log("ARS:         0x6E3358Bc9E80b72a2F1E971Ae5e5E75D29a1a4c2");
        console.log("GHS:         0xd2B1132937315B4161670B652F8D158D39bAf2D5");
        console.log("USDC:        0x1fFdf1a9DB25c1b1Ed8f3026d98e4349d01234C3");
        console.log("Oracle:      ", ORACLE);
        console.log("PoolManager: ", POOL_MANAGER);
        console.log("Hook:        ", hookAddress);
        console.log("\nNext: Run CreatePools script to create the trading pools");
    }
}

// Dummy contract to increment nonce
contract DummyContract {
    uint256 public value = 1;
}
