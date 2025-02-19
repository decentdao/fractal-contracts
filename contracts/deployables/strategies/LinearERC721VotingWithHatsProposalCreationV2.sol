// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LinearERC721VotingV1} from "./LinearERC721VotingV1.sol";
import {ERC4337VoterSupportV1} from "./ERC4337VoterSupportV1.sol";
import {LinearERC721VotingWithHatsProposalCreationV1} from "./LinearERC721VotingWithHatsProposalCreationV1.sol";
import {IVersion} from "../../interfaces/decent/deployables/IVersion.sol";

/**
 * An [Azorius](./Azorius.md) [BaseStrategy](./BaseStrategy.md) implementation that
 * enables linear (i.e. 1 to 1) ERC721 based token voting, with proposal creation
 * restricted to users wearing whitelisted Hats.
 */
contract LinearERC721VotingWithHatsProposalCreationV2 is
    LinearERC721VotingWithHatsProposalCreationV1,
    IVersion,
    ERC4337VoterSupportV1
{
    /** @inheritdoc IVersion*/
    function getVersion() external pure override returns (uint16) {
        // Although this function is implemented by parent class, we want them to have independent versionings
        // This should be incremented whenever the contract is modified
        return 2;
    }

    /** @inheritdoc LinearERC721VotingV1*/
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
}
