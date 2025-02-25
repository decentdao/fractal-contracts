// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.28;

import {DecentHatsModuleUtils} from "../utilities/DecentHatsModuleUtils.sol";

contract MockDecentHatsModuleUtils is DecentHatsModuleUtils {
    // Expose the internal _processHat function for testing
    function processRoleHats(CreateRoleHatsParams calldata params) external {
        _processRoleHats(params);
    }
}
