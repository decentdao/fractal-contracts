// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.19;

import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { BaseStrategy, IBaseStrategy } from "../BaseStrategy.sol";
import { BaseQuorumPercent } from "../BaseQuorumPercent.sol";
import { BaseVotingBasisPercent } from "../BaseVotingBasisPercent.sol";

abstract contract LinearERC20MultipleChoiceVoting is BaseStrategy, BaseQuorumPercent {

    /**
     * Defines the current state of votes on a particular Proposal.
     */
    struct ProposalVotes {
        uint32 votingStartBlock; // block that voting starts at
        uint32 votingEndBlock; // block that voting ends
        address[] choices; // addresses to be voted on
        uint32 votingLimit; // number of choices each voter can select
        uint256 votes; // total vote weight
        mapping(address => uint256) voteCount; // how many votes each address receives
        mapping(address => bool) hasVoted; // whether a given address has voted yet or not
    }

    struct AddressVote {
        address choice;
        uint256 voteCount;
    }

    IVotes public governanceToken;

    /** Number of blocks a new Proposal can be voted on. */
    uint32 public votingPeriod;

    /** Voting weight required to be able to submit Proposals. */
    uint256 public requiredProposerWeight;

    /** `proposalId` to `ProposalVotes`, the voting state of a Proposal. */
    mapping(uint256 => ProposalVotes) public proposalVotes;

    event VotingPeriodUpdated(uint32 votingPeriod);
    event RequiredProposerWeightUpdated(uint256 requiredProposerWeight);
    event ProposalInitialized(uint32 proposalId, uint32 votingEndBlock);

    event Voted(
        address voter,
        uint32 proposalId,
        address[] choices,
        uint256 weight
    );

    error InvalidProposal();
    error VotingEnded();
    error AlreadyVoted();
    error InvalidVote();
    error InvalidTokenAddress();
    error OverChoicesLimit();

    /**
     * Sets up the contract with its initial parameters.
     *
     * @param initializeParams encoded initialization parameters: `address _owner`,
     * `IVotes _governanceToken`, `address _azoriusModule`, `uint32 _votingPeriod`,
     * `uint256 _requiredProposerWeight`, `uint256 _quorumNumerator`,
     * `uint256 _basisNumerator`
     */
    function setUp(
        bytes memory initializeParams
    ) public virtual override initializer {
        (
            address _owner,
            IVotes _governanceToken,
            address _azoriusModule,
            uint32 _votingPeriod,
            uint256 _requiredProposerWeight,
            uint256 _quorumNumerator
        ) = abi.decode(
                initializeParams,
                (address, IVotes, address, uint32, uint256, uint256)
            );
        if (address(_governanceToken) == address(0))
            revert InvalidTokenAddress();

        governanceToken = _governanceToken;
        __Ownable_init();
        transferOwnership(_owner);
        _setAzorius(_azoriusModule);
        _updateQuorumNumerator(_quorumNumerator);
        _updateVotingPeriod(_votingPeriod);
        _updateRequiredProposerWeight(_requiredProposerWeight);

        emit StrategySetUp(_azoriusModule, _owner);
    }

    /**
     * Updates the voting time period for new Proposals.
     *
     * @param _votingPeriod voting time period (in blocks)
     */
    function updateVotingPeriod(
        uint32 _votingPeriod
    ) external virtual onlyOwner {
        _updateVotingPeriod(_votingPeriod);
    }

    /**
     * Updates the voting weight required to submit new Proposals.
     *
     * @param _requiredProposerWeight required token voting weight
     */
    function updateRequiredProposerWeight(
        uint256 _requiredProposerWeight
    ) external virtual onlyOwner {
        _updateRequiredProposerWeight(_requiredProposerWeight);
    }

    /**
     * Casts votes for a Proposal, equal to the caller's token delegation.
     *
     * @param _proposalId id of the Proposal to vote on
     * @param _choices Choices to vote for
     */
    function vote(uint32 _proposalId, address[] calldata _choices) external virtual {
        _vote(
            _proposalId,
            msg.sender,
            _choices,
            getVotingWeight(msg.sender, _proposalId)
        );
    }

    /**
     * Returns the current state of the specified Proposal.
     *
     * @param _proposalId id of the Proposal
     * @return choiceVotes current count of votes each choice has received=
     * @return startBlock block number voting starts
     * @return endBlock block number voting ends
     */
    function getProposalVotes(
        uint32 _proposalId
    )
        external
        view
        virtual
        returns (
            AddressVote[] memory choiceVotes,
            uint32 startBlock,
            uint32 endBlock,
            uint256 votingSupply
        )
    {
        choiceVotes = _voted(_proposalId);
        startBlock = proposalVotes[_proposalId].votingStartBlock;
        endBlock = proposalVotes[_proposalId].votingEndBlock;
        votingSupply = getProposalVotingSupply(_proposalId);
    }

    function _voted(uint32 _proposalId) internal view returns (AddressVote[] memory) {
        ProposalVotes storage proposal = proposalVotes[_proposalId];

        AddressVote[] memory voted = new AddressVote[](proposal.choices.length);

        for (uint256 i = 0; i < proposal.choices.length; i++) {
            address choice = proposal.choices[i];
            voted[i] = AddressVote({choice: choice, voteCount: proposal.voteCount[choice]});
        }
        return voted;
    }

    /** @inheritdoc BaseStrategy*/
    function initializeProposal(
        bytes memory _data
    ) public virtual override onlyAzorius {
        uint32 proposalId = abi.decode(_data, (uint32));
        uint32 _votingEndBlock = uint32(block.number) + votingPeriod;

        proposalVotes[proposalId].votingEndBlock = _votingEndBlock;
        proposalVotes[proposalId].votingStartBlock = uint32(block.number);

        emit ProposalInitialized(proposalId, _votingEndBlock);
    }

    /**
     * Returns whether an address has voted on the specified Proposal.
     *
     * @param _proposalId id of the Proposal to check
     * @param _address address to check
     * @return bool true if the address has voted on the Proposal, otherwise false
     */
    function hasVoted(
        uint32 _proposalId,
        address _address
    ) public view virtual returns (bool) {
        return proposalVotes[_proposalId].hasVoted[_address];
    }

    /** @inheritdoc BaseStrategy*/
    function isPassed(
        uint32 _proposalId
    ) public view virtual override returns (bool) {
        return (block.number > proposalVotes[_proposalId].votingEndBlock && // voting period has ended
            meetsQuorum(
                getProposalVotingSupply(_proposalId),
                proposalVotes[_proposalId].votes
            )); // votes meets the quorum
    }

    /**
     * Calculates whether a vote meets quorum. This is calculated based on yes votes + abstain
     * votes.
     *
     * @param _totalSupply the total supply of tokens
     * @param _votes number of votes
     * @return bool whether the total number of votes meets the quorum
     */
    function meetsQuorum(uint256 _totalSupply, uint256 _votes) public view returns (bool) {
        return _votes >= (_totalSupply * quorumNumerator) / QUORUM_DENOMINATOR;
    }

    /**
     * Returns a snapshot of total voting supply for a given Proposal.  Because token supplies can change,
     * it is necessary to calculate quorum from the supply available at the time of the Proposal's creation,
     * not when it is being voted on passes / fails.
     *
     * @param _proposalId id of the Proposal
     * @return uint256 voting supply snapshot for the given _proposalId
     */
    function getProposalVotingSupply(
        uint32 _proposalId
    ) public view virtual returns (uint256) {
        return
            governanceToken.getPastTotalSupply(
                proposalVotes[_proposalId].votingStartBlock
            );
    }

    /**
     * Calculates the voting weight an address has for a specific Proposal.
     *
     * @param _voter address of the voter
     * @param _proposalId id of the Proposal
     * @return uint256 the address' voting weight
     */
    function getVotingWeight(
        address _voter,
        uint32 _proposalId
    ) public view virtual returns (uint256) {
        return
            governanceToken.getPastVotes(
                _voter,
                proposalVotes[_proposalId].votingStartBlock
            );
    }

    /** @inheritdoc BaseStrategy*/
    function isProposer(
        address _address
    ) public view virtual override returns (bool) {
        return
            governanceToken.getPastVotes(_address, block.number - 1) >=
            requiredProposerWeight;
    }

    /** @inheritdoc BaseStrategy*/
    function votingEndBlock(
        uint32 _proposalId
    ) public view virtual override returns (uint32) {
        return proposalVotes[_proposalId].votingEndBlock;
    }

    /** Internal implementation of `updateVotingPeriod`. */
    function _updateVotingPeriod(uint32 _votingPeriod) internal virtual {
        votingPeriod = _votingPeriod;
        emit VotingPeriodUpdated(_votingPeriod);
    }

    /** Internal implementation of `updateRequiredProposerWeight`. */
    function _updateRequiredProposerWeight(
        uint256 _requiredProposerWeight
    ) internal virtual {
        requiredProposerWeight = _requiredProposerWeight;
        emit RequiredProposerWeightUpdated(_requiredProposerWeight);
    }

    function _vote(
        uint32 _proposalId,
        address _voter,
        address[] memory _choices,
        uint256 _weight
        )  internal virtual {
        ProposalVotes storage proposal = proposalVotes[_proposalId];
        if (proposal.votingEndBlock == 0)
            revert InvalidProposal();
        if (block.number > proposal.votingEndBlock)
            revert VotingEnded();
        if (proposal.hasVoted[_voter]) 
            revert AlreadyVoted();
        if (_choices.length <= proposal.votingLimit)
            revert OverChoicesLimit();

        proposal.hasVoted[_voter] = true;
        proposal.votes += _weight;
        for (uint256 i = 0; i < _choices.length; i++) {
            proposal.voteCount[_choices[i]] += _weight;
        }
        emit Voted(_voter, _proposalId, _choices, _weight);
    }
}