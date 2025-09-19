// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/StreetRateHookStandalone.sol";

contract FixDeviationScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address hookAddress = 0x09ACf156789F81E854c4aE594f16Ec1E241d97aD; // Your deployed hook address
        
        vm.startBroadcast(deployerPrivateKey);
        
        StreetRateHookStandalone hook = StreetRateHookStandalone(hookAddress);
        
        // Update deviation threshold to 8000 basis points (80%)
        // This allows for realistic street rate differences
        hook.updateDeviationThreshold(8000);
        
        console.log("Updated deviation threshold to 80%");
        
        vm.stopBroadcast();
    }
}