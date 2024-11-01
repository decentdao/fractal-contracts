// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IDecentVersion} from "../IDecentVersion.sol";
import {IHats} from "../hats/IHats.sol";

interface IDecentAutonomousAdminV1 is IDecentVersion {
    error NotCurrentWearer();

    struct TriggerStartArgs {
        address currentWearer;
        IHats hatsProtocol;
        uint256 hatId;
        address nominatedWearer;
    }

    function triggerStartNextTerm(TriggerStartArgs calldata args) external;
}
