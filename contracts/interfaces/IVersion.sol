//SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

/**
 * Interface of functions for versioned contracts
 */
interface IVersion {
    /**
     * Returns the current version of the contract
     *
     */
    function getVersion() external pure returns (uint16);
}
