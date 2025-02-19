//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * struct of voting NFT
 */
struct ERC721VotingToken {
    address tokenAddress;
    uint256 tokenId;
}

struct ERC721VotingWeight {
    uint256 weight;
    ERC721VotingToken[] tokens;
}

/**
 * Interface of functions for retrieving voting weights
 */
interface IERC721VotingWeight {
    /**
     * Returns voting weight if a proposal is done right now
     * Will be used to gate access to draft proposals and comments
     */
    function votingWeight(
        address _address,
        address[] calldata _tokenAddresses,
        uint256[] calldata _tokenIds
    ) external view returns (uint256);

    /**
     * Returns unused voting tokens for a proposal
     * FE should use the result value for the tokenAddresses and tokenIds for the vote() function
     */
    function unusedVotingPower(
        address _address,
        uint32 _proposalId,
        address[] calldata _tokenAddresses,
        uint256[] calldata _tokenIds
    ) external view returns (ERC721VotingWeight memory);
}
