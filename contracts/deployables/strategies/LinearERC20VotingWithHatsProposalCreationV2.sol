// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.19;

import {LinearERC20Voting} from "./LinearERC20Voting.sol";
import {ERC4337VoterSupport} from "./ERC4337VoterSupport.sol";
import {LinearERC20VotingWithHatsProposalCreation} from "./LinearERC20VotingWithHatsProposalCreation.sol";
import {IVersion} from "../../interfaces/decent/IVersion.sol";

/**
 * An [Azorius](./Azorius.md) [BaseStrategy](./BaseStrategy.md) implementation that
 * enables linear (i.e. 1 to 1) ERC20 based token voting, with proposal creation
 * restricted to users wearing whitelisted Hats.
 */
contract LinearERC20VotingWithHatsProposalCreationV2 is
    LinearERC20VotingWithHatsProposalCreation,
    IVersion,
    ERC4337VoterSupport
{
    /** @inheritdoc IVersion*/
    function getVersion() external pure override returns (uint16) {
        // Although this function is implemented by parent class, we want them to have independent versionings
        // This should be incremented whenever the contract is modified
        return 2;
    }

    /** @inheritdoc LinearERC20Voting*/
    function vote(
        uint32 _proposalId,
        uint8 _voteType
    ) external virtual override {
        address voter = _voter(msg.sender);
        _vote(
            _proposalId,
            voter,
            _voteType,
            getVotingWeight(voter, _proposalId)
        );
    }
}
