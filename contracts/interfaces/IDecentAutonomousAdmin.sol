// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IHats} from "./hats/full/IHats.sol";

interface IDecentAutonomousAdmin {
    struct TriggerStartArgs {
        address currentWearer;
        IHats hatsProtocol;
        uint256 hatId;
        address nominatedWearer;
    }

    function triggerStartNextTerm(TriggerStartArgs calldata args) external;
}
