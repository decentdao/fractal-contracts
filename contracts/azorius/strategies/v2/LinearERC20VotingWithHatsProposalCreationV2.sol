// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.19;

import {LinearERC20VotingWithHatsProposalCreation} from "../LinearERC20VotingWithHatsProposalCreation.sol";
import {LinearERC20VotingExtensible} from "../LinearERC20VotingExtensible.sol";
import {IVersion} from "../../../interfaces/IVersion.sol";
import {ERC4337VoterSupport} from "./ERC4337VoterSupport.sol";
import {IBaseStrategy} from "../../interfaces/IBaseStrategy.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * An [Azorius](./Azorius.md) [BaseStrategy](./BaseStrategy.md) implementation that
 * enables linear (i.e. 1 to 1) ERC20 based token voting, with proposal creation
 * restricted to users wearing whitelisted Hats.
 */
contract LinearERC20VotingWithHatsProposalCreationV2 is
    LinearERC20VotingWithHatsProposalCreation,
    IVersion,
    ERC4337VoterSupport,
    ERC165
{
    /** @inheritdoc IVersion*/
    function getVersion() external pure override returns (uint16) {
        // Although this function is implemented by parent class, we want them to have independent versionings
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
