// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Enum} from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import {IAvatar} from "@gnosis.pm/zodiac/contracts/interfaces/IAvatar.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC6551Registry} from "./interfaces/IERC6551Registry.sol";
import {IHats} from "./interfaces/hats/full/IHats.sol";
import {LockupLinear, Broker} from "./interfaces/sablier/full/types/DataTypes.sol";
import {IHatsModuleFactory} from "./interfaces/hats/full/IHatsModuleFactory.sol";
import {IHatsElectionsEligibility} from "./interfaces/hats/full/modules/IHatsElectionsEligibility.sol";
import {ModuleProxyFactory} from "@gnosis.pm/zodiac/contracts/factory/ModuleProxyFactory.sol";
import {ISablierV2LockupLinear} from "./interfaces/sablier/ISablierV2LockupLinear.sol";

contract DecentHatsCreationModule {
    bytes32 public constant SALT =
        0x5d0e6ce4fd951366cc55da93f6e79d8b81483109d79676a04bcc2bed6a4b5072;

    struct TopHatParams {
        string details;
        string imageURI;
    }

    struct AdminHatParams {
        string details;
        string imageURI;
        bool isMutable;
    }

    struct SablierStreamParams {
        ISablierV2LockupLinear sablier;
        address sender;
        address asset;
        LockupLinear.Timestamps timestamps;
        Broker broker;
        uint128 totalAmount;
        bool cancelable;
        bool transferable;
    }

    struct HatParams {
        address wearer;
        string details;
        string imageURI;
        uint32 maxSupply;
        bool isMutable;
        uint128 termEndDateTs;
        SablierStreamParams[] sablierStreamsParams;
    }

    struct CreateTreeParams {
        IHats hatsProtocol;
        IERC6551Registry erc6551Registry;
        IHatsModuleFactory hatsModuleFactory;
        ModuleProxyFactory moduleProxyFactory;
        address keyValuePairs;
        address decentAutonomousAdminMasterCopy;
        address hatsAccountImplementation;
        address hatsElectionsEligibilityImplementation;
        TopHatParams topHat;
        AdminHatParams adminHat;
        HatParams[] hats;
    }

    /* /////////////////////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    ///////////////////////////////////////////////////////////////////////////// */
    /**
     * @notice For a safe without any roles previously created on it, this function should be called. It sets up the
     * top hat and admin hat, as well as any other hats and their streams that are provided, then transfers the top hat
     * to the calling safe.
     *
     * @notice This contract should be enabled a module on the Safe for which the role(s) are to be created, and disabled after.
     *
     * @dev For each hat that is included, if the hat is:
     *  - termed, its stream funds on are targeted directly at the nominated wearer. The wearer should directly call `withdraw-`
     *    on the Sablier contract.
     *  - untermed, its stream funds are targeted at the hat's smart account. In order to withdraw funds from the stream, the
     * hat's smart account must be the one call to `withdraw-` on the Sablier contract, setting the recipient arg to its wearer.
     *
     * @dev In order for a Safe to seamlessly create roles even if it has never previously created a role and thus has
     * no hat tree, we defer the creation of the hat tree and its setup to this contract. This way, in a single tx block,
     * the resulting topHatId of the newly created hat can be used to create an admin hat and any other hats needed.
     * We also make use of `KeyValuePairs` to associate the topHatId with the Safe.
     */
    function createAndDeclareTree(CreateTreeParams calldata params) external {
        IHats hatsProtocol = params.hatsProtocol;
        address hatsAccountImplementation = params.hatsAccountImplementation;
        IERC6551Registry registry = params.erc6551Registry;

        // Create Top Hat
        (uint256 topHatId, address topHatAccount) = processTopHat(
            hatsProtocol,
            registry,
            hatsAccountImplementation,
            params.keyValuePairs,
            params.topHat
        );

        // Create Admin Hat
        uint256 adminHatId = processAdminHat(
            hatsProtocol,
            registry,
            hatsAccountImplementation,
            topHatId,
            topHatAccount,
            params.moduleProxyFactory,
            params.decentAutonomousAdminMasterCopy,
            params.adminHat
        );

        for (uint256 i = 0; i < params.hats.length; ) {
            HatParams memory hat = params.hats[i];
            processHat(
                hatsProtocol,
                registry,
                hatsAccountImplementation,
                topHatId,
                topHatAccount,
                params.hatsModuleFactory,
                params.hatsElectionsEligibilityImplementation,
                adminHatId,
                hat
            );

            unchecked {
                ++i;
            }
        }

        hatsProtocol.transferHat(topHatId, address(this), msg.sender);
    }

    /* /////////////////////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    ///////////////////////////////////////////////////////////////////////////// */

    function processTopHat(
        IHats hatsProtocol,
        IERC6551Registry registry,
        address hatsAccountImplementation,
        address keyValuePairs,
        TopHatParams memory topHat
    ) internal returns (uint256 topHatId, address topHatAccount) {
        // Mint top hat
        topHatId = hatsProtocol.mintTopHat(
            address(this),
            topHat.details,
            topHat.imageURI
        );

        // Create top hat account
        topHatAccount = registry.createAccount(
            hatsAccountImplementation,
            SALT,
            block.chainid,
            address(hatsProtocol),
            topHatId
        );

        // Declare Top Hat ID to Safe via KeyValuePairs
        string[] memory keys = new string[](1);
        string[] memory values = new string[](1);
        keys[0] = "topHatId";
        values[0] = Strings.toString(topHatId);
        IAvatar(msg.sender).execTransactionFromModule(
            keyValuePairs,
            0,
            abi.encodeWithSignature(
                "updateValues(string[],string[])",
                keys,
                values
            ),
            Enum.Operation.Call
        );
    }

    function processAdminHat(
        IHats hatsProtocol,
        IERC6551Registry registry,
        address hatsAccountImplementation,
        uint256 topHatId,
        address topHatAccount,
        ModuleProxyFactory moduleProxyFactory,
        address decentAutonomousAdminMasterCopy,
        AdminHatParams memory adminHat
    ) internal returns (uint256 adminHatId) {
        // Create Admin Hat
        adminHatId = hatsProtocol.createHat(
            topHatId,
            adminHat.details,
            1, // only one Admin Hat
            topHatAccount,
            topHatAccount,
            adminHat.isMutable,
            adminHat.imageURI
        );

        // Create Admin Hat's ERC6551 Account
        registry.createAccount(
            hatsAccountImplementation,
            SALT,
            block.chainid,
            address(hatsProtocol),
            adminHatId
        );

        // Deploy Decent Autonomous Admin Module, which will wear the Admin Hat
        address autonomousAdminModule = moduleProxyFactory.deployModule(
            decentAutonomousAdminMasterCopy,
            abi.encodeWithSignature("setUp(bytes)", bytes("")),
            uint256(
                keccak256(
                    abi.encodePacked(
                        // for the salt, we'll concatenate our static salt with the id of the Admin Hat
                        SALT,
                        adminHatId
                    )
                )
            )
        );

        // Mint Hat to the Decent Autonomous Admin Module
        hatsProtocol.mintHat(adminHatId, autonomousAdminModule);
    }

    function processHat(
        IHats hatsProtocol,
        IERC6551Registry registry,
        address hatsAccountImplementation,
        uint256 topHatId,
        address topHatAccount,
        IHatsModuleFactory hatsModuleFactory,
        address hatsElectionsEligibilityImplementation,
        uint256 adminHatId,
        HatParams memory hat
    ) internal {
        // Create eligibility module if needed
        address eligibilityAddress = createEligibilityModule(
            hatsProtocol,
            hatsModuleFactory,
            hatsElectionsEligibilityImplementation,
            topHatId,
            topHatAccount,
            adminHatId,
            hat.termEndDateTs
        );

        // Create and Mint the Role Hat
        uint256 hatId = createAndMintHat(
            hatsProtocol,
            adminHatId,
            hat,
            eligibilityAddress,
            topHatAccount
        );

        // Get the stream recipient (based on termed or not)
        address streamRecipient = setupStreamRecipient(
            registry,
            hatsAccountImplementation,
            address(hatsProtocol),
            hat.termEndDateTs,
            hat.wearer,
            hatId
        );

        // Create streams
        createSablierStreams(hat.sablierStreamsParams, streamRecipient);
    }

    // Exists to avoid stack too deep errors
    function createEligibilityModule(
        IHats hatsProtocol,
        IHatsModuleFactory hatsModuleFactory,
        address hatsElectionsEligibilityImplementation,
        uint256 topHatId,
        address topHatAccount,
        uint256 adminHatId,
        uint128 termEndDateTs
    ) internal returns (address) {
        if (termEndDateTs != 0) {
            return
                hatsModuleFactory.createHatsModule(
                    hatsElectionsEligibilityImplementation,
                    hatsProtocol.getNextId(adminHatId),
                    abi.encode(topHatId, uint256(0)), // [BALLOT_BOX_ID, ADMIN_HAT_ID]
                    abi.encode(termEndDateTs),
                    uint256(SALT)
                );
        }
        return topHatAccount;
    }

    // Exists to avoid stack too deep errors
    function createAndMintHat(
        IHats hatsProtocol,
        uint256 adminHatId,
        HatParams memory hat,
        address eligibilityAddress,
        address topHatAccount
    ) internal returns (uint256) {
        uint256 hatId = hatsProtocol.createHat(
            adminHatId,
            hat.details,
            hat.maxSupply,
            eligibilityAddress,
            topHatAccount,
            hat.isMutable,
            hat.imageURI
        );

        // If the hat is termed, nominate the wearer as the eligible member
        if (hat.termEndDateTs != 0) {
            address[] memory nominatedWearers = new address[](1);
            nominatedWearers[0] = hat.wearer;
            IHatsElectionsEligibility(eligibilityAddress).elect(
                hat.termEndDateTs,
                nominatedWearers
            );
        }

        hatsProtocol.mintHat(hatId, hat.wearer);
        return hatId;
    }

    // Exists to avoid stack too deep errors
    function setupStreamRecipient(
        IERC6551Registry registry,
        address hatsAccountImplementation,
        address hatsProtocol,
        uint128 termEndDateTs,
        address wearer,
        uint256 hatId
    ) internal returns (address) {
        // If the hat is termed, the wearer is the stream recipient
        if (termEndDateTs != 0) {
            return wearer;
        }

        // Otherwise, the Hat's smart account is the stream recipient
        return
            registry.createAccount(
                hatsAccountImplementation,
                SALT,
                block.chainid,
                hatsProtocol,
                hatId
            );
    }

    // Exists to avoid stack too deep errors
    function processSablierStream(
        SablierStreamParams memory streamParams,
        address streamRecipient
    ) internal {
        // Approve tokens for Sablier via a proxy call through the Safe
        IAvatar(msg.sender).execTransactionFromModule(
            streamParams.asset,
            0,
            abi.encodeWithSignature(
                "approve(address,uint256)",
                streamParams.sablier,
                streamParams.totalAmount
            ),
            Enum.Operation.Call
        );

        // Proxy the Sablier call through the Safe
        IAvatar(msg.sender).execTransactionFromModule(
            address(streamParams.sablier),
            0,
            abi.encodeWithSignature(
                "createWithTimestamps((address,address,uint128,address,bool,bool,(uint40,uint40,uint40),(address,uint256)))",
                LockupLinear.CreateWithTimestamps({
                    sender: streamParams.sender,
                    recipient: streamRecipient,
                    totalAmount: streamParams.totalAmount,
                    asset: IERC20(streamParams.asset),
                    cancelable: streamParams.cancelable,
                    transferable: streamParams.transferable,
                    timestamps: streamParams.timestamps,
                    broker: streamParams.broker
                })
            ),
            Enum.Operation.Call
        );
    }

    // Exists to avoid stack too deep errors
    function createSablierStreams(
        SablierStreamParams[] memory streamParams,
        address streamRecipient
    ) internal {
        for (uint256 i = 0; i < streamParams.length; ) {
            processSablierStream(streamParams[i], streamRecipient);

            unchecked {
                ++i;
            }
        }
    }
}
