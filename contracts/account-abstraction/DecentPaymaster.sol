// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BasePaymaster, IEntryPoint} from "@account-abstraction/contracts/core/BasePaymaster.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/IPaymaster.sol";
import {UserOperationLib} from "@account-abstraction/contracts/core/UserOperationLib.sol";

contract DecentPaymaster is BasePaymaster {
    // Mapping: strategy address => function selector => is approved
    mapping(address => mapping(bytes4 => bool)) public approvedFunctions;

    event FunctionApproved(address strategy, bytes4 selector, bool approved);

    error UnauthorizedStrategy();
    error InvalidCallDataLength();

    constructor(IEntryPoint _entryPoint) BasePaymaster(_entryPoint) {
        // Initialize with EntryPoint address
    }

    /**
     * Add or remove approved functions for a strategy contract
     * @param strategy The strategy contract address
     * @param selectors Array of function selectors to approve/disapprove
     * @param approved Whether to approve or remove approval for the selectors
     */
    function setStrategyFunctionApproval(
        address strategy,
        bytes4[] calldata selectors,
        bool[] calldata approved
    ) external onlyOwner {
        require(selectors.length == approved.length, "Invalid input length");
        for (uint256 i = 0; i < selectors.length; i++) {
            approvedFunctions[strategy][selectors[i]] = approved[i];
            emit FunctionApproved(strategy, selectors[i], approved[i]);
        }
    }

    /**
     * Check if a function is approved for a strategy
     * @param strategy The strategy contract address
     * @param selector The function selector to check
     * @return bool Whether the function is approved
     */
    function isFunctionApproved(
        address strategy,
        bytes4 selector
    ) public view returns (bool) {
        return approvedFunctions[strategy][selector];
    }

    /// @inheritdoc BasePaymaster
    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32,
        uint256
    )
        internal
        view
        override
        returns (bytes memory context, uint256 validationData)
    {
        bytes calldata callData = userOp.callData;

        // Require minimum length for selector and target address
        if (callData.length < 24) {
            revert InvalidCallDataLength();
        }

        // Extract function selector and target address
        bytes4 selector = bytes4(callData[:4]);
        address target;
        assembly {
            target := shr(96, calldataload(add(callData.offset, 4)))
        }

        // Verify the function is approved for this strategy
        if (!isFunctionApproved(target, selector)) {
            revert UnauthorizedStrategy();
        }

        return (abi.encode(), 0);
    }
}
