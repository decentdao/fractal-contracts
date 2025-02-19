// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {LinearERC721VotingWithHatsProposalCreation} from "../LinearERC721VotingWithHatsProposalCreation.sol";
import {LinearERC721VotingExtensible} from "../LinearERC721VotingExtensible.sol";
import {IVersion} from "../../../interfaces/IVersion.sol";
import {ERC721VotingWeight, IERC721VotingWeight} from "../../../interfaces/IERC721VotingWeight.sol";
import {ERC4337VoterSupport} from "./ERC4337VoterSupport.sol";
import {ERC721VotingWeightSupport} from "./ERC721VotingWeightSupport.sol";

/**
 * An [Azorius](./Azorius.md) [BaseStrategy](./BaseStrategy.md) implementation that
 * enables linear (i.e. 1 to 1) ERC721 based token voting, with proposal creation
 * restricted to users wearing whitelisted Hats.
 */
contract LinearERC721VotingWithHatsProposalCreationV2 is
    LinearERC721VotingWithHatsProposalCreation,
    IVersion,
    IERC721VotingWeight,
    ERC4337VoterSupport,
    ERC721VotingWeightSupport
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
        ERC721VotingWeightSupport.ERC721VoterAndWeight
            memory voterAndVotingWeight = this._voterAndWeight(
                msg.sender,
                _proposalId,
                _tokenAddresses,
                _tokenIds
            );
        /*
            This can be more efficient if we pass voterAndVotingWeight._weight into _vote()
            */
        _vote(
            _proposalId,
            voterAndVotingWeight._address,
            _voteType,
            _tokenAddresses,
            _tokenIds
        );
    }

    /** @inheritdoc IERC721VotingWeight*/
    function votingWeight(
        address _address,
        address[] memory _tokenAddresses,
        uint256[] memory _tokenIds
    ) external view override returns (uint256) {
        require(_tokenAddresses.length == _tokenIds.length);
        return
            _votingWeight(_address, tokenWeights, _tokenAddresses, _tokenIds);
    }

    /** @inheritdoc IERC721VotingWeight*/
    function unusedVotingWeight(
        address _address,
        uint32 _proposalId,
        address[] memory _tokenAddresses,
        uint256[] memory _tokenIds
    ) public view override returns (ERC721VotingWeight memory) {
        require(_tokenAddresses.length == _tokenIds.length);
        return
            _unusedVotingPower(
                _address,
                _proposalId,
                tokenWeights,
                proposalVotes,
                _tokenAddresses,
                _tokenIds
            );
    }
}
