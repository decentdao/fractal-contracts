// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IDecentAutonomousAdmin} from "./IDecentAutonomousAdmin.sol";
import {IHats} from "../hats/IHats.sol";

interface IDecentAutonomousAdminV1 is IDecentAutonomousAdmin {
    error NotCurrentWearer();

    struct TriggerStartArgs {
        address currentWearer;
        IHats hatsProtocol;
        uint256 hatId;
        address nominatedWearer;
    }

    function triggerStartNextTerm(TriggerStartArgs calldata args) external;
}
