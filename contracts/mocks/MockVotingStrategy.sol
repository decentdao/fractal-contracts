// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.28;

import {BaseStrategy} from "../deployables/strategies/BaseStrategy.sol";

/**
 * A mock [BaseStrategy](../BaseStrategy.md) used only for testing purposes.
 * Not intended for actual on-chain use.
 */
contract MockVotingStrategy is BaseStrategy {
    address public proposer;

    /**
     * Sets up the contract with its initial parameters.
     *
     * @param initializeParams encoded initialization parameters
     */
    function setUp(bytes memory initializeParams) public override initializer {
        address _proposer = abi.decode(initializeParams, (address));
        proposer = _proposer;
    }

    /** @inheritdoc BaseStrategy*/
    function initializeProposal(bytes memory _data) external override {}

    /** @inheritdoc BaseStrategy*/
    function isPassed(uint32) external pure override returns (bool) {
        return false;
    }

    /** @inheritdoc BaseStrategy*/
    function isProposer(
        address _proposer
    ) external view override returns (bool) {
        return _proposer == proposer;
    }

    /** @inheritdoc BaseStrategy*/
    function votingEndBlock(uint32) external pure override returns (uint32) {
        return 0;
    }
}
