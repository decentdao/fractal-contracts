// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IHats} from "../../hats/IHats.sol";

interface IDecentAutonomousAdminV1 {
    error NotCurrentWearer();

    struct TriggerStartArgs {
        address currentWearer;
        IHats hatsProtocol;
        uint256 hatId;
        address nominatedWearer;
    }

    function triggerStartNextTerm(TriggerStartArgs calldata args) external;
}
