// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./StreetRateHookStandalone.sol";
import "./HybridRateOracle.sol";

/// @title HookDeployer
/// @notice Deploys StreetRateHook using CREATE2 to get a deterministic address with correct flags
contract HookDeployer {
    /// @notice The flags we want for our hook (beforeSwap enabled)
    uint256 public constant REQUIRED_FLAGS = 0x80; // beforeSwap flag (bit 7)
    
    /// @notice Deploy the hook using CREATE2
    /// @param salt The salt to use for CREATE2
    /// @param oracle The oracle address to use
    /// @param deviationThreshold The deviation threshold in basis points
    /// @return hook The deployed hook address
    function deployHook(
        bytes32 salt,
        IStreetRateOracle oracle,
        uint256 deviationThreshold
    ) external returns (StreetRateHookStandalone hook) {
        // Deploy using CREATE2
        hook = new StreetRateHookStandalone{salt: salt}(oracle, deviationThreshold);
        
        // Verify the address has the correct flags
        require(hasCorrectFlags(address(hook)), "Hook address does not have correct flags");
        
        return hook;
    }
    
    /// @notice Compute the address that would be deployed with given parameters
    /// @param salt The salt to use
    /// @param oracle The oracle address
    /// @param deviationThreshold The deviation threshold
    /// @return The address that would be deployed
    function computeHookAddress(
        bytes32 salt,
        IStreetRateOracle oracle,
        uint256 deviationThreshold
    ) external view returns (address) {
        bytes memory bytecode = type(StreetRateHookStandalone).creationCode;
        bytes memory constructorArgs = abi.encode(oracle, deviationThreshold);
        
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(abi.encodePacked(bytecode, constructorArgs))
            )
        );
        
        return address(uint160(uint256(hash)));
    }
    
    /// @notice Find a salt that produces an address with the correct flags
    /// @param oracle The oracle address
    /// @param deviationThreshold The deviation threshold
    /// @param maxIterations Maximum number of iterations to try
    /// @return salt The salt that produces a valid address
    /// @return hookAddress The resulting hook address
    function findSalt(
        IStreetRateOracle oracle,
        uint256 deviationThreshold,
        uint256 maxIterations
    ) external view returns (bytes32 salt, address hookAddress) {
        bytes memory bytecode = type(StreetRateHookStandalone).creationCode;
        bytes memory constructorArgs = abi.encode(oracle, deviationThreshold);
        bytes32 initCodeHash = keccak256(abi.encodePacked(bytecode, constructorArgs));
        
        for (uint256 i = 0; i < maxIterations; i++) {
            salt = bytes32(i);
            
            bytes32 hash = keccak256(
                abi.encodePacked(
                    bytes1(0xff),
                    address(this),
                    salt,
                    initCodeHash
                )
            );
            
            hookAddress = address(uint160(uint256(hash)));
            
            if (hasCorrectFlags(hookAddress)) {
                return (salt, hookAddress);
            }
        }
        
        revert("Could not find suitable salt");
    }
    
    /// @notice Check if an address has the correct hook flags
    /// @param hookAddress The address to check
    /// @return Whether the address has the correct flags
    function hasCorrectFlags(address hookAddress) public pure returns (bool) {
        // Get the last 2 bytes of the address
        uint256 addressBits = uint256(uint160(hookAddress));
        uint256 lastTwoBytes = addressBits & 0xFFFF;
        
        // Check if beforeSwap flag (bit 7) is set
        // For our hook, we need beforeSwap enabled
        return (lastTwoBytes & REQUIRED_FLAGS) == REQUIRED_FLAGS;
    }
    
    /// @notice Get the flags from a hook address
    /// @param hookAddress The hook address
    /// @return The flags encoded in the address
    function getFlags(address hookAddress) external pure returns (uint256) {
        uint256 addressBits = uint256(uint160(hookAddress));
        return addressBits & 0xFFFF;
    }
}
