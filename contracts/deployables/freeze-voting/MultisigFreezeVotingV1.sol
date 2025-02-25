// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.28;

import {IVersion} from "../../interfaces/decent/deployables/IVersion.sol";
import {BaseFreezeVotingV1} from "./BaseFreezeVotingV1.sol";
import {ISafe} from "../../interfaces/safe/ISafe.sol";

/**
 * A BaseFreezeVoting implementation which handles freezes on multi-sig (Safe) based DAOs.
 */
contract MultisigFreezeVotingV1 is BaseFreezeVotingV1 {
    ISafe public parentGnosisSafe;

    event MultisigFreezeVotingSetup(
        address indexed owner,
        address indexed parentGnosisSafe
    );

    error NotOwner();
    error AlreadyVoted();

    /**
     * Initialize function, will be triggered when a new instance is deployed.
     *
     * @param initializeParams encoded initialization parameters: `address _owner`,
     * `uint256 _freezeVotesThreshold`, `uint256 _freezeProposalPeriod`, `uint256 _freezePeriod`,
     * `address _parentGnosisSafe`
     */
    function setUp(bytes memory initializeParams) public override initializer {
        (
            address _owner,
            uint256 _freezeVotesThreshold,
            uint32 _freezeProposalPeriod,
            uint32 _freezePeriod,
            address _parentGnosisSafe
        ) = abi.decode(
                initializeParams,
                (address, uint256, uint32, uint32, address)
            );

        __Ownable_init(_owner);
        _updateFreezeVotesThreshold(_freezeVotesThreshold);
        _updateFreezeProposalPeriod(_freezeProposalPeriod);
        _updateFreezePeriod(_freezePeriod);
        parentGnosisSafe = ISafe(_parentGnosisSafe);

        emit MultisigFreezeVotingSetup(_owner, _parentGnosisSafe);
    }

    /** @inheritdoc BaseFreezeVotingV1*/
    function castFreezeVote() external override {
        if (!parentGnosisSafe.isOwner(msg.sender)) revert NotOwner();

        if (block.number > freezeProposalCreatedBlock + freezeProposalPeriod) {
            // create a new freeze proposal and count the caller's vote

            freezeProposalCreatedBlock = uint32(block.number);

            freezeProposalVoteCount = 1;

            emit FreezeProposalCreated(msg.sender);
        } else {
            // there is an existing freeze proposal, count the caller's vote

            if (userHasFreezeVoted[msg.sender][freezeProposalCreatedBlock])
                revert AlreadyVoted();

            freezeProposalVoteCount++;
        }

        userHasFreezeVoted[msg.sender][freezeProposalCreatedBlock] = true;

        emit FreezeVoteCast(msg.sender, 1);
    }

    /// @inheritdoc IVersion
    function getVersion() external pure virtual override returns (uint16) {
        return 1;
    }
}
