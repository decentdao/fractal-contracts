// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "./BaseTokenVoting.sol";
import "./BaseQuorumPercent.sol";

/// @title An Azorius strategy that enables linear token voting
contract LinearTokenVoting is BaseTokenVoting, BaseQuorumPercent {
    ERC20Votes public governanceToken;

    error InvalidTokenAddress();

    /// @notice Sets up the contract with initial parameters
    /// @param initParams The initial setup parameters encoded as bytes
    function setUp(bytes memory initParams) public override initializer {
        (
            address _owner,
            ERC20Votes _governanceToken,
            address _azoriusModule,
            uint256 _votingPeriod,
            uint256 _quorumNumerator,
            string memory _name
        ) = abi.decode(
                initParams,
                (address, ERC20Votes, address, uint256, uint256, string)
            );
        if (address(_governanceToken) == address(0))
            revert InvalidTokenAddress();

        // todo: get rid of name
        name = _name;
        governanceToken = _governanceToken;
        __Ownable_init();
        transferOwnership(_owner);
        _setAzorius(_azoriusModule);
        _updateQuorumNumerator(_quorumNumerator);
        _updateVotingPeriod(_votingPeriod);

        emit StrategySetup(_azoriusModule, _owner);
    }

    /// @notice Casts a vote for a proposal
    /// @param _proposalId The ID of the proposal to vote for
    /// @param _support Proposal support represented as NO, YES, or ABSTAIN
    function vote(uint256 _proposalId, uint8 _support, bytes memory) external {
        _vote(
            _proposalId,
            msg.sender,
            _support,
            getVotingWeight(msg.sender, _proposalId)
        );
    }

    /// @notice Returns if a proposal has succeeded
    /// @param _proposalId The ID of the proposal to check
    /// @return bool True if the proposal has passed
    function isPassed(uint256 _proposalId) external view override returns (bool) {
        if (
            proposals[_proposalId].yesVotes > proposals[_proposalId].noVotes &&
            proposals[_proposalId].yesVotes >=
            quorum(proposals[_proposalId].votingStartBlock) &&
            proposals[_proposalId].votingEndBlock != 0 &&
            block.number > proposals[_proposalId].votingEndBlock
        ) {
            return true;
        }

        return false;
    }

    /// @notice Calculates the number of token votes needed for quorum at a specific block number
    /// @param _blockNumber The block number to calculate quorum at
    /// @return uint256 The number of token votes needed for quorum
    function quorum(
        uint256 _blockNumber
    ) public view override returns (uint256) {
        return
            (governanceToken.getPastTotalSupply(_blockNumber) *
                quorumNumerator) / quorumDenominator;
    }

    /// @notice Calculates the voting weight an address has for a specific proposal
    /// @param _voter Address of the voter
    /// @param _proposalId The ID of the proposal
    /// @return uint256 The user's vote count
    function getVotingWeight(
        address _voter,
        uint256 _proposalId
    ) public view returns (uint256) {
        return
            governanceToken.getPastVotes(
                _voter,
                proposals[_proposalId].votingStartBlock
            );
    }

    /// @notice Returns if the specified address can submit a proposal
    /// @return bool True if the user can submit a proposal
    function isProposer(address) public pure override returns (bool) {
        return true;
    }
}
