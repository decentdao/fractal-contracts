// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.28;

import {DecentHatsModuleUtils} from "./DecentHatsModuleUtils.sol";

contract DecentHatsModificationModule is DecentHatsModuleUtils {
    /**
     * @notice Creates a new termed or untermed role hat and any streams on it.
     *
     * @notice This contract should be enabled a module on the Safe for which the role is to be created, and disabled after.
     *
     * @dev Stream funds on untermed Roles are targeted at the hat's smart account. In order to withdraw funds from the stream, the
     * hat's smart account must be the one call to `withdraw-` on the Sablier contract, setting the recipient arg to its wearer.
     *
     * @dev Stream funds on termed Roles are targeted directly at the nominated wearer.
     * The wearer should directly call `withdraw-` on the Sablier contract.
     *
     * @dev Role hat creation, minting, smart account creation and stream creation are handled here in order
     * to avoid a race condition where not more than one active proposal to create a new role can exist at a time.
     * See: https://github.com/decentdao/decent-interface/issues/2402
     *
     * @param roleHatsParams An array of params for each role hat to be created.
     */
    function createRoleHats(
        CreateRoleHatsParams calldata roleHatsParams
    ) external {
        _processRoleHats(roleHatsParams);
    }
}
