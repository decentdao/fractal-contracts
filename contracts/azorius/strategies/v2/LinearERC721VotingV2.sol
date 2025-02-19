// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.19;

import {LinearERC721VotingExtensible} from "../LinearERC721VotingExtensible.sol";
import {IVersion} from "../../../interfaces/IVersion.sol";
import {ERC721VotingWeight, IERC721VotingWeight} from "../../../interfaces/IERC721VotingWeight.sol";
import {ERC4337VoterSupport} from "./ERC4337VoterSupport.sol";
import {ERC721VotingWeightSupport} from "./ERC721VotingWeightSupport.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * An Azorius strategy that allows multiple ERC721 tokens to be registered as governance tokens,
 * each with their own voting weight.
 *
 * This is slightly different from ERC-20 voting, since there is no way to snapshot ERC721 holdings.
 * Each ERC721 id can vote once, reguardless of what address held it when a proposal was created.
 *
 * Also, this uses "quorumThreshold" rather than LinearERC20Voting's quorumPercent, because the
 * total supply of NFTs is not knowable within the IERC721 interface.  This is similar to a multisig
 * "total signers" required, rather than a percentage of the tokens.
 */
contract LinearERC721VotingV2 is
    LinearERC721VotingExtensible,
    IVersion,
    IERC721VotingWeight,
    ERC4337VoterSupport,
    ERC721VotingWeightSupport
{
    /** @inheritdoc IVersion*/
    function getVersion() external pure virtual returns (uint16) {
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

    /** @inheritdoc IERC721VotingWeight*/
    function votingWeight(
        address _address,
        address[] memory _tokenAddresses,
        uint256[] memory _tokenIds
    ) external view override returns (uint256) {
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
