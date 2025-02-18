// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.19;

import {LinearERC20VotingExtensible} from "../LinearERC20VotingExtensible.sol";
import {IVersion} from "../../../interfaces/IVersion.sol";
import {ERC4337VoterSupport} from "./ERC4337VoterSupport.sol";
import {IBaseStrategy} from "../../interfaces/IBaseStrategy.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * An [Azorius](./Azorius.md) [BaseStrategy](./BaseStrategy.md) implementation that
 * enables linear (i.e. 1 to 1) token voting. Each token delegated to a given address
 * in an `ERC20Votes` token equals 1 vote for a Proposal.
 */
contract LinearERC20VotingV2 is
    LinearERC20VotingExtensible,
    IVersion,
    ERC4337VoterSupport,
    ERC165
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

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IVersion).interfaceId ||
            interfaceId == type(IBaseStrategy).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
