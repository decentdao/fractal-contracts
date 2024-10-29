// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IHats} from "./hats/full/IHats.sol";

interface IDecentAutonomousAdmin {
    struct TriggerStartArgs {
        address currentWearer;
        IHats userHatProtocol;
        uint256 userHatId;
        address nominatedWearer;
    }

    function triggerStartNextTerm(TriggerStartArgs calldata args) external;
}
