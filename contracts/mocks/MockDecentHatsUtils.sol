// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {DecentHatsModuleUtils} from "../modules/DecentHatsModuleUtils.sol";

contract MockDecentHatsModuleUtils is DecentHatsModuleUtils {
    // Expose the internal _processHat function for testing
    function processRoleHats(CreateRoleHatsParams calldata params) external {
        _processRoleHats(params);
    }
}
