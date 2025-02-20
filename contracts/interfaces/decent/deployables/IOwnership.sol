// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.28;

/**
 * Interface to get the owner of a smart account
 */
interface IOwnership {
    /**
     * @notice Returns the owner address of this contract
     * @dev This can return either an EOA address for regular voters, or a smart contract address like a DAO Safe
     * @return The address of the owner
     */
    function owner() external view returns (address);
}
