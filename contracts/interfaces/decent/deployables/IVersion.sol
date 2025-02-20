// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.28;

/**
 * Interface of functions for versioned contracts
 */
interface IVersion {
    /**
     * Returns the current version of the contract
     */
    function getVersion() external pure returns (uint16);
}
