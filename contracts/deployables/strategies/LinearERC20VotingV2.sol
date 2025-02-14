// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.19;

import {IVersion} from "../../interfaces/decent/IVersion.sol";
import {LinearERC20Voting} from "./LinearERC20Voting.sol";
import {ERC4337VoterSupport} from "./ERC4337VoterSupport.sol";

/**
 * An [Azorius](./Azorius.md) [BaseStrategy](./BaseStrategy.md) implementation that
 * enables linear (i.e. 1 to 1) token voting. Each token delegated to a given address
 * in an `ERC20Votes` token equals 1 vote for a Proposal.
 */
contract LinearERC20VotingV2 is
    IVersion,
    LinearERC20Voting,
    ERC4337VoterSupport
{
    /** @inheritdoc IVersion*/
    function getVersion() external pure virtual returns (uint16) {
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
