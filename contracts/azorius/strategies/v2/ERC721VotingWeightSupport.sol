// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.19;

import {ERC721VotingToken, ERC721VotingWeight, IERC721VotingWeight} from "../../../interfaces/IERC721VotingWeight.sol";
import {LinearERC721VotingExtensible} from "../LinearERC721VotingExtensible.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC4337VoterSupport} from "./ERC4337VoterSupport.sol";

abstract contract ERC721VotingWeightSupport is
    IERC721VotingWeight,
    ERC4337VoterSupport
{
    struct ERC721VoterAndWeight {
        address _address;
        ERC721VotingWeight _votingWeight;
    }

    function _votingWeight(
        address _address,
        mapping(address => uint256) storage _tokenWeights,
        address[] memory _tokenAddresses,
        uint256[] memory _tokenIds
    ) internal view returns (uint256) {
        uint256 weight;

        for (uint256 i = 0; i < _tokenAddresses.length; ) {
            address tokenAddress = _tokenAddresses[i];
            uint256 tokenId = _tokenIds[i];

            require(
                _address == IERC721(tokenAddress).ownerOf(tokenId),
                "Not owned"
            );
            weight += _tokenWeights[tokenAddress];
            unchecked {
                ++i;
            }
        }
        return weight;
    }

    function _unusedVotingPower(
        address _address,
        uint32 _proposalId,
        mapping(address => uint256) storage _tokenWeights,
        mapping(uint256 => LinearERC721VotingExtensible.ProposalVotes)
            storage _proposalVotes,
        address[] memory _tokenAddresses,
        uint256[] memory _tokenIds
    ) internal view returns (ERC721VotingWeight memory) {
        ERC721VotingToken[] memory tokens = new ERC721VotingToken[](
            _tokenAddresses.length
        );
        uint256 weight;
        uint32 count;

        for (uint256 i = 0; i < _tokenAddresses.length; ) {
            address tokenAddress = _tokenAddresses[i];
            uint256 tokenId = _tokenIds[i];

            require(
                _address == IERC721(tokenAddress).ownerOf(tokenId),
                "Not owned"
            );

            if (
                _proposalVotes[_proposalId].hasVoted[tokenAddress][tokenId] !=
                true
            ) {
                weight += _tokenWeights[tokenAddress];
                ERC721VotingToken memory token;
                token.tokenAddress = tokenAddress;
                token.tokenId = tokenId;
                tokens[count] = token;
                count++;
            }
            unchecked {
                ++i;
            }
        }

        ERC721VotingWeight memory result;
        result.weight = weight;
        if (count == _tokenAddresses.length) {
            result.tokens = tokens;
        } else {
            // Condense the result array
            ERC721VotingToken[] memory unvoted = new ERC721VotingToken[](count);
            for (uint32 i = 0; i < count; i++) {
                unvoted[i] = tokens[i];
            }
            result.tokens = unvoted;
        }

        return result;
    }

    function _voterAndWeight(
        address _address,
        uint32 _proposalId,
        address[] memory _tokenAddresses,
        uint256[] memory _tokenIds
    ) public view returns (ERC721VoterAndWeight memory) {
        try
            this.unusedVotingWeight(
                _address,
                _proposalId,
                _tokenAddresses,
                _tokenIds
            )
        returns (ERC721VotingWeight memory votingWeight) {
            return ERC721VoterAndWeight(_address, votingWeight);
        } catch Error(string memory reason) {
            address voter = _voter(_address);
            if (voter == _address) revert(reason);
            return
                ERC721VoterAndWeight(
                    voter,
                    this.unusedVotingWeight(
                        voter,
                        _proposalId,
                        _tokenAddresses,
                        _tokenIds
                    )
                );
        }
    }
}
