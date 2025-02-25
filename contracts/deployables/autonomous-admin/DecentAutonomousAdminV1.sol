// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.28;

import {IHatsElectionsEligibility} from "../../interfaces/hats/modules/IHatsElectionsEligibility.sol";
import {IDecentAutonomousAdminV1} from "../../interfaces/decent/deployables/IDecentAutonomousAdminV1.sol";
import {IVersion} from "../../interfaces/decent/deployables/IVersion.sol";
import {FactoryFriendly} from "@gnosis-guild/zodiac/contracts/factory/FactoryFriendly.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract DecentAutonomousAdminV1 is
    IDecentAutonomousAdminV1,
    IVersion,
    ERC165,
    FactoryFriendly
{
    // //////////////////////////////////////////////////////////////
    //                         initializer
    // //////////////////////////////////////////////////////////////
    function setUp(bytes memory initializeParams) public override initializer {}

    // //////////////////////////////////////////////////////////////
    //                         Public Functions
    // //////////////////////////////////////////////////////////////
    function triggerStartNextTerm(TriggerStartArgs calldata args) public {
        IHatsElectionsEligibility hatsElectionModule = IHatsElectionsEligibility(
                args.hatsProtocol.getHatEligibilityModule(args.hatId)
            );

        hatsElectionModule.startNextTerm();

        // This will burn the hat if wearer is no longer eligible
        args.hatsProtocol.checkHatWearerStatus(args.hatId, args.currentWearer);

        // This will mint the hat to the nominated wearer, if necessary
        if (args.nominatedWearer != args.currentWearer) {
            args.hatsProtocol.mintHat(args.hatId, args.nominatedWearer);
        }
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return
            interfaceId == type(IDecentAutonomousAdminV1).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IVersion
    function getVersion() external pure virtual returns (uint16) {
        return 1;
    }
}
