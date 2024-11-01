// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {IHatsElectionsEligibility} from "../interfaces/hats/modules/IHatsElectionsEligibility.sol";

contract MockHatsElectionsEligibility is IHatsElectionsEligibility {
    // Storage
    mapping(uint128 termEnd => mapping(address candidates => bool elected))
        public electionResults;
    mapping(uint128 termEnd => bool isElectionOpen) public electionStatus;
    uint128 public currentTermEnd;
    uint128 public nextTermEnd;

    // Errors
    error AlreadySetup();
    error ElectionNotOpen();
    error InvalidTermEnd();
    error NoActiveElection();
    error ElectionClosed(uint128 termEnd);
    error TermNotEnded();
    error NextTermNotReady();
    error TooManyWinners();

    modifier onlyOnce() {
        if (currentTermEnd != 0) revert AlreadySetup();
        _;
    }

    function _setUp(bytes calldata _initData) external onlyOnce {
        // decode init data
        uint128 _firstTermEnd = abi.decode(_initData, (uint128));
        require(
            _firstTermEnd > block.timestamp,
            "First term must end in the future"
        );

        currentTermEnd = _firstTermEnd;

        // open the first election
        electionStatus[_firstTermEnd] = true;

        // log the first term
        emit ElectionOpened(_firstTermEnd);
    }

    function elect(uint128 _termEnd, address[] calldata _winners) external {
        // results can only be submitted for open elections
        if (!electionStatus[_termEnd]) revert ElectionClosed(_termEnd);

        // close the election
        electionStatus[_termEnd] = false;

        // set the election results
        for (uint256 i; i < _winners.length; ) {
            electionResults[_termEnd][_winners[i]] = true;

            unchecked {
                ++i;
            }
        }

        // log the election results
        emit ElectionCompleted(_termEnd, _winners);
    }

    function recall(uint128 _termEnd, address[] calldata _recallees) external {
        // loop through the accounts and set their election status to false
        for (uint256 i; i < _recallees.length; ) {
            electionResults[_termEnd][_recallees[i]] = false;

            unchecked {
                ++i;
            }
        }

        emit Recalled(_termEnd, _recallees);
    }

    function setNextTerm(uint128 _newTermEnd) external {
        // new term must end after current term
        if (_newTermEnd <= currentTermEnd) revert InvalidTermEnd();

        // if next term is already set, its election must still be open
        uint128 next = nextTermEnd;
        if (next > 0 && !electionStatus[next]) revert ElectionClosed(next);

        // set the next term
        nextTermEnd = _newTermEnd;

        // open the next election
        electionStatus[_newTermEnd] = true;

        // log the new term
        emit ElectionOpened(_newTermEnd);
    }

    function startNextTerm() external {
        // current term must be over
        if (block.timestamp < currentTermEnd) revert TermNotEnded();

        uint128 next = nextTermEnd; // save SLOADs

        // next term must be set and its election must be closed
        if (next == 0 || electionStatus[next]) revert NextTermNotReady();

        // set the current term to the next term
        currentTermEnd = next;

        // clear the next term
        nextTermEnd = 0;

        // log the change
        emit NewTermStarted(next);
    }

    function getWearerStatus(
        address _wearer,
        uint256 /* _hatId */
    ) public view override returns (bool eligible, bool standing) {
        /// @dev This eligibility module is not concerned with standing, so we default it to good standing
        standing = true;

        uint128 current = currentTermEnd; // save SLOAD

        if (block.timestamp < current) {
            // if the current term is still open, the wearer is eligible if they have been elected for the current term
            eligible = electionResults[current][_wearer];
        }
        // if the current term is closed, the wearer is not eligible
    }

    // // Test helper functions
    // function setWearerStatus(address wearer, bool eligible) external {
    //     electionResults[currentTermEnd][wearer] = eligible;
    // }

    function BALLOT_BOX_HAT() external pure override returns (uint256) {}

    function ADMIN_HAT() external pure override returns (uint256) {}
}
