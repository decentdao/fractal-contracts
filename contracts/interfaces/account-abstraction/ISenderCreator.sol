// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISenderCreator {
    /**
     * @dev Creates a new sender contract.
     * @return sender Address of the newly created sender contract.
     */
    function createSender(
        bytes calldata initCode
    ) external returns (address sender);
}
