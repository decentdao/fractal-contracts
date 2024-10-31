// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {IHatsElectionsEligibility} from "../interfaces/hats/modules/IHatsElectionsEligibility.sol";

contract MockHatsElectionsEligibility is IHatsElectionsEligibility {
    function currentTermEnd() external view returns (uint128) {}

    function nextTermEnd() external view returns (uint128) {}

    function electionStatus(
        uint128 termEnd
    ) external view returns (bool isElectionOpen) {}

    function electionResults(
        uint128 termEnd,
        address candidate
    ) external view returns (bool elected) {}

    function BALLOT_BOX_HAT() external pure returns (uint256) {}

    function ADMIN_HAT() external pure returns (uint256) {}

    function elect(uint128 _termEnd, address[] calldata _winners) external {}

    function recall(uint128 _termEnd, address[] calldata _recallees) external {}

    function setNextTerm(uint128 _newTermEnd) external {}

    function startNextTerm() external {}

    function getWearerStatus(
        address,
        uint256
    ) external pure returns (bool eligible, bool standing) {
        return (true, true);
    }
}
