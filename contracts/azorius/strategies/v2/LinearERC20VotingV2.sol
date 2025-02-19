// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.19;

import {LinearERC20VotingExtensible} from "../LinearERC20VotingExtensible.sol";
import {IVersion} from "../../../interfaces/IVersion.sol";
import {IERC20VotingWeight} from "../../../interfaces/IERC20VotingWeight.sol";
import {ERC4337VoterSupport} from "./ERC4337VoterSupport.sol";

/**
 * An [Azorius](./Azorius.md) [BaseStrategy](./BaseStrategy.md) implementation that
 * enables linear (i.e. 1 to 1) token voting. Each token delegated to a given address
 * in an `ERC20Votes` token equals 1 vote for a Proposal.
 */
contract LinearERC20VotingV2 is
    LinearERC20VotingExtensible,
    IVersion,
    IERC20VotingWeight,
    ERC4337VoterSupport
{
    /** @inheritdoc IVersion*/
    function getVersion() external pure virtual returns (uint16) {
        // This should be incremented whenever the contract is modified
        return 2;
    }

    /** @inheritdoc LinearERC20VotingExtensible*/
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

    /** @inheritdoc IERC20VotingWeight*/
    function votingWeight(
        address _address
    ) external view override returns (uint256) {
        return governanceToken.getVotes(_address);
    }

    /** @inheritdoc IERC20VotingWeight*/
    function unusedVotingWeight(
        address _address,
        uint32 _proposalId
    ) public view override returns (uint256) {
        // This is the same as LinearERC20VotingExtensible.getVotingWeight except external vs public
        return
            governanceToken.getPastVotes(
                _address,
                proposalVotes[_proposalId].votingStartBlock
            );
    }
}
