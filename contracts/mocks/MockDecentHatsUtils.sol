// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {DecentHatsModuleUtils} from "../modules/DecentHatsModuleUtils.sol";
import {IHats} from "../interfaces/hats/IHats.sol";
import {IERC6551Registry} from "../interfaces/IERC6551Registry.sol";
import {IHatsModuleFactory} from "../interfaces/hats/IHatsModuleFactory.sol";

contract MockDecentHatsModuleUtils is DecentHatsModuleUtils {
    // Expose the internal _processHat function for testing
    function processHat(
        IHats hatsProtocol,
        IERC6551Registry erc6551Registry,
        address hatsAccountImplementation,
        uint256 topHatId,
        address topHatAccount,
        IHatsModuleFactory hatsModuleFactory,
        address hatsElectionsEligibilityImplementation,
        uint256 adminHatId,
        HatParams memory hat
    ) external {
        _processHat(
            hatsProtocol,
            erc6551Registry,
            hatsAccountImplementation,
            topHatId,
            topHatAccount,
            hatsModuleFactory,
            hatsElectionsEligibilityImplementation,
            adminHatId,
            hat
        );
    }
}
