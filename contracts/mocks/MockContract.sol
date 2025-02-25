// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.28;

/**
 * Mock contract for testing
 */
contract MockContract {
    event DidSomething(string message);

    error Reverting();

    function doSomething() public {
        doSomethingWithParam("doSomething()");
    }

    function doSomethingWithParam(string memory _message) public {
        emit DidSomething(_message);
    }

    function returnSomething(
        string memory _s
    ) external pure returns (string memory) {
        return _s;
    }

    function revertSomething() external pure {
        revert Reverting();
    }
}
