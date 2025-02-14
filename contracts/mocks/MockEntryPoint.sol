// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;

import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract MockEntryPoint is IEntryPoint, IERC165 {
    mapping(address => uint256) public balances;
    mapping(address => uint256) public stakes;
    mapping(address => uint256) public unstakeDelaySecs;
    mapping(address => mapping(uint192 => uint256)) public nonces;
    mapping(address => IStakeManager.DepositInfo) public deposits;

    function depositTo(address account) external payable {
        balances[account] += msg.value;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function addStake(uint32 unstakeDelaySec) external payable {
        stakes[msg.sender] = msg.value;
        unstakeDelaySecs[msg.sender] = unstakeDelaySec;
    }

    function unlockStake() external {
        // Mock implementation
    }

    function withdrawStake(address payable withdrawAddress) external {
        uint256 stake = stakes[msg.sender];
        require(stake > 0, "No stake to withdraw");
        stakes[msg.sender] = 0;
        (bool success, ) = withdrawAddress.call{value: stake}("");
        require(success, "Transfer failed");
    }

    function withdrawTo(
        address payable withdrawAddress,
        uint256 amount
    ) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        (bool success, ) = withdrawAddress.call{value: amount}("");
        require(success, "Transfer failed");
    }

    function handleOps(
        PackedUserOperation[] calldata,
        address payable
    ) external pure {
        // Mock implementation
    }

    function handleAggregatedOps(
        UserOpsPerAggregator[] calldata,
        address payable
    ) external pure {
        // Mock implementation
    }

    function simulateValidation(PackedUserOperation calldata) external pure {
        // Mock implementation
    }

    function simulateHandleOp(
        PackedUserOperation calldata,
        address,
        bytes calldata
    ) external pure {
        // Mock implementation
    }

    function getNonce(
        address sender,
        uint192 key
    ) external view returns (uint256) {
        return nonces[sender][key];
    }

    function incrementNonce(uint192 key) external {
        nonces[msg.sender][key]++;
    }

    function getUserOpHash(
        PackedUserOperation calldata
    ) external pure returns (bytes32) {
        return bytes32(0);
    }

    function getDepositInfo(
        address account
    ) external view returns (IStakeManager.DepositInfo memory) {
        return deposits[account];
    }

    function getSenderAddress(bytes memory) external pure {
        // Mock implementation
    }

    function delegateAndRevert(address, bytes calldata) external pure {
        // Mock implementation
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return
            interfaceId == type(IEntryPoint).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    receive() external payable {
        // Accept ETH transfers
    }
}
