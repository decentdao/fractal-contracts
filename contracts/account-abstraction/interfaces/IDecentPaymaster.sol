// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IDecentPaymaster {
    function setStrategyFunctionApproval(
        address strategy,
        bytes4[] calldata selectors,
        bool[] calldata approved
    ) external;

    function isFunctionApproved(
        address strategy,
        bytes4 selector
    ) external view returns (bool);

    function setUp(bytes memory initializeParams) external;
}
