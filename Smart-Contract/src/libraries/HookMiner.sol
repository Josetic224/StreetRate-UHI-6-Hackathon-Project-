// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title HookMiner
/// @notice Library for finding salt values that produce hook addresses with the correct flags
library HookMiner {
    uint256 constant BEFORE_SWAP_FLAG = 1 << 7;
    uint256 constant AFTER_SWAP_FLAG = 1 << 6;
    uint256 constant BEFORE_ADD_LIQUIDITY_FLAG = 1 << 5;
    uint256 constant AFTER_ADD_LIQUIDITY_FLAG = 1 << 4;
    uint256 constant BEFORE_REMOVE_LIQUIDITY_FLAG = 1 << 3;
    uint256 constant AFTER_REMOVE_LIQUIDITY_FLAG = 1 << 2;
    uint256 constant BEFORE_DONATE_FLAG = 1 << 1;
    uint256 constant AFTER_DONATE_FLAG = 1 << 0;

    /// @notice Find a salt that produces a hook address with the desired flags
    /// @param deployer The address that will deploy the hook
    /// @param flags The desired flags for the hook address
    /// @param creationCode The creation code of the hook contract
    /// @param constructorArgs The encoded constructor arguments
    /// @return salt The salt value that produces the desired address
    /// @return hookAddress The resulting hook address
    function find(
        address deployer,
        uint256 flags,
        bytes memory creationCode,
        bytes memory constructorArgs
    ) internal pure returns (bytes32 salt, address hookAddress) {
        bytes32 initCodeHash = keccak256(abi.encodePacked(creationCode, constructorArgs));
        
        uint256 seed = 0;
        while (true) {
            salt = bytes32(seed);
            hookAddress = computeAddress(deployer, salt, initCodeHash);
            
            if (matchesFlags(hookAddress, flags)) {
                return (salt, hookAddress);
            }
            
            seed++;
            
            // Prevent infinite loop
            require(seed < 100000, "Could not find suitable salt");
        }
    }
    
    /// @notice Compute the CREATE2 address
    /// @param deployer The address that will deploy the contract
    /// @param salt The salt value
    /// @param initCodeHash The hash of the init code
    /// @return The computed address
    function computeAddress(
        address deployer,
        bytes32 salt,
        bytes32 initCodeHash
    ) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            deployer,
            salt,
            initCodeHash
        )))));
    }
    
    /// @notice Check if an address matches the desired hook flags
    /// @param hookAddress The address to check
    /// @param flags The desired flags
    /// @return Whether the address matches the flags
    function matchesFlags(address hookAddress, uint256 flags) internal pure returns (bool) {
        // Get the last 2 bytes of the address
        uint256 addressBits = uint256(uint160(hookAddress));
        uint256 lastTwoBytes = addressBits & 0xFFFF;
        
        // Check if the required flags are set
        return (lastTwoBytes & flags) == flags;
    }
    
    /// @notice Get the flags from a hook address
    /// @param hookAddress The hook address
    /// @return The flags encoded in the address
    function getFlags(address hookAddress) internal pure returns (uint256) {
        uint256 addressBits = uint256(uint160(hookAddress));
        return addressBits & 0xFFFF;
    }
}
