// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {LinearERC721VotingWithHatsProposalCreation} from "../LinearERC721VotingWithHatsProposalCreation.sol";
import {LinearERC721VotingExtensible} from "../LinearERC721VotingExtensible.sol";
import {IVersion} from "../../../interfaces/IVersion.sol";
import {ERC4337VoterSupport} from "./ERC4337VoterSupport.sol";
import {IBaseStrategy} from "../../interfaces/IBaseStrategy.sol";
import {IERC721VotingStrategy} from "../../interfaces/IERC721VotingStrategy.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * An [Azorius](./Azorius.md) [BaseStrategy](./BaseStrategy.md) implementation that
 * enables linear (i.e. 1 to 1) ERC721 based token voting, with proposal creation
 * restricted to users wearing whitelisted Hats.
 */
contract LinearERC721VotingWithHatsProposalCreationV2 is
    LinearERC721VotingWithHatsProposalCreation,
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

    /** @inheritdoc LinearERC721VotingExtensible*/
    function vote(
        uint32 _proposalId,
        uint8 _voteType,
        address[] memory _tokenAddresses,
        uint256[] memory _tokenIds
    ) external virtual override {
        if (_tokenAddresses.length != _tokenIds.length) revert InvalidParams();
        _vote(
            _proposalId,
            _voter(msg.sender),
            _voteType,
            _tokenAddresses,
            _tokenIds
        );
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IVersion).interfaceId ||
            interfaceId == type(IBaseStrategy).interfaceId ||
            interfaceId == type(IERC721VotingStrategy).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
