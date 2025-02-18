//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * Interface of functions for retrieving voting weights
 */
interface IERC20VotingWeight {
    /**
     * Returns voting weight if a proposal is done right now
     * Will be used to gate access to draft proposals and comments
     */
    function votingWeight(address _address) external view returns (uint256);

    /**
     * Returns unused voting weight for a proposal
     *
     */
    function unusedVotingWeight(
        address _address,
        uint32 _proposalId
    ) external view returns (uint256);
}
