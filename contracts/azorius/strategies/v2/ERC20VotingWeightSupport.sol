// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.19;

import {IERC20VotingWeight} from "../../../interfaces/IERC20VotingWeight.sol";
import {ERC4337VoterSupport} from "./ERC4337VoterSupport.sol";

abstract contract ERC20VotingWeightSupport is
    IERC20VotingWeight,
    ERC4337VoterSupport
{
    struct ERC20VoterAndWeight {
        address _address;
        uint256 _weight;
    }

    function _voterAndWeight(
        address _address,
        uint32 _proposalId
    ) public view returns (ERC20VoterAndWeight memory) {
        uint256 votingWeight = this.unusedVotingWeight(_address, _proposalId);
        // uint256 votingWeight = unusedVotingWeight(_address, _proposalId);
        if (votingWeight > 0) {
            return ERC20VoterAndWeight(_address, votingWeight);
        } else {
            address voter = _voter(_address);
            if (voter != _address) {
                return
                    ERC20VoterAndWeight(
                        voter,
                        this.unusedVotingWeight(voter, _proposalId)
                    );
            } else {
                return ERC20VoterAndWeight(_address, 0);
            }
        }
    }
}
