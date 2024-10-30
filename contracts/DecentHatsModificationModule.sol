// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC6551Registry} from "./interfaces/IERC6551Registry.sol";
import {IHats} from "./interfaces/hats/full/IHats.sol";
import {IHatsModuleFactory} from "./interfaces/hats/full/IHatsModuleFactory.sol";
import {DecentHatsUtils} from "./DecentHatsUtils.sol";

contract DecentHatsModificationModule is DecentHatsUtils {
    struct CreateTermedOrUntermedRoleHatParams {
        IHats hatsProtocol;
        IERC6551Registry registry;
        address topHatAccount;
        address hatsAccountImplementation;
        uint256 adminHatId;
        uint256 topHatId;
        HatParams hat;
        address hatsElectionsEligibilityImplementation;
        IHatsModuleFactory hatsModuleFactory;
    }

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
     */
    function createTestFobarrNewRoleHat(
        CreateTermedOrUntermedRoleHatParams calldata params
    ) external {
        _processHat(
            params.hatsProtocol,
            params.registry,
            params.hatsAccountImplementation,
            params.topHatId,
            params.topHatAccount,
            params.hatsModuleFactory,
            params.hatsElectionsEligibilityImplementation,
            params.adminHatId,
            params.hat
        );
    }
}
