// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.28;

contract MockNonOwnership {
    // This contract intentionally does not implement IOwnership
    // It's used to test the catch block in ERC4337VoterSupport._voter

    function someFunction() external pure returns (bool) {
        return true;
    }
}
