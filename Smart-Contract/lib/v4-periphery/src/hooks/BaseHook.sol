// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

contract BaseHook is Test {
    // Minimal mock implementation for testing
    error InvalidHook();
    
    function beforeSwap(
        address,
        address,
        bytes32,
        IPoolManager.SwapParams calldata
    ) external virtual returns (uint256, uint256) {
        return (0, 0);
    }
    
    function afterSwap(
        address,
        address,
        bytes32,
        IPoolManager.SwapParams calldata,
        IPoolManager.SwapResult memory
    ) external virtual {
        // No-op
    }
}
