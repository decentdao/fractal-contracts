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
import {IHatsElectionEligibility} from "./interfaces/hats/full/IHatsElectionEligibility.sol";
import {ModuleProxyFactory} from "@gnosis.pm/zodiac/contracts/factory/ModuleProxyFactory.sol";
import {ISablierV2LockupLinear} from "./interfaces/sablier/ISablierV2LockupLinear.sol";

contract DecentHats {
    bytes32 public constant SALT =
        0x5d0e6ce4fd951366cc55da93f6e79d8b81483109d79676a04bcc2bed6a4b5072;

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

    struct TermedParam {
        uint128 termEndDateTs;
        address nominatedWearer;
    }

    struct Hat {
        address wearer;
        string details;
        string imageURI;
        SablierStreamParams[] sablierParams;
        TermedParam termedParam;
        uint32 maxSupply;
        bool isMutable;
    }

    struct CreateTreeParams {
        IHats hatsProtocol;
        IERC6551Registry registry;
        IHatsModuleFactory hatsModuleFactory;
        ModuleProxyFactory moduleProxyFactory;
        address decentAutonomousAdminMasterCopy;
        address hatsAccountImplementation;
        address keyValuePairs;
        address hatsElectionEligibilityImplementation;
        Hat adminHat;
        Hat[] hats;
        string topHatDetails;
        string topHatImageURI;
    }

    struct CreateRoleHatParams {
        IHats hatsProtocol;
        IERC6551Registry registry;
        address topHatAccount;
        address hatsAccountImplementation;
        uint256 adminHatId;
        uint256 topHatId;
        Hat hat;
    }

    struct CreateTermedRoleHatParams {
        IHats hatsProtocol;
        IERC6551Registry registry;
        IHatsModuleFactory hatsModuleFactory;
        address topHatAccount;
        address hatsAccountImplementation;
        address hatsElectionEligibilityImplementation;
        uint256 adminHatId;
        uint256 topHatId;
        Hat hat;
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
        (uint256 topHatId, address topHatAccount) = _createTopHatAndAccount(
            params.hatsProtocol,
            params.topHatDetails,
            params.topHatImageURI,
            params.registry,
            params.hatsAccountImplementation
        );

        _declareSafeHatTree(params.keyValuePairs, topHatId);

        (uint256 adminHatId, ) = _createAdminHatAndAccount(
            params.hatsProtocol,
            params.registry,
            params.moduleProxyFactory,
            params.decentAutonomousAdminMasterCopy,
            params.hatsAccountImplementation,
            topHatAccount,
            topHatId,
            params.adminHat
        );

        for (uint256 i = 0; i < params.hats.length; ) {
            // {assuption} if 0 nominatedWearers, then it is not a termed role
            if (params.hats[i].termedParam.nominatedWearer != address(0)) {
                // Create election module and set as eligiblity
                _createTermedHatAndAccountAndMintAndStreams(
                    params.hatsProtocol,
                    topHatAccount,
                    params.hatsModuleFactory.createHatsModule(
                        params.hatsElectionEligibilityImplementation,
                        params.hatsProtocol.getNextId(adminHatId),
                        abi.encode(topHatId, uint256(0)),
                        abi.encode(params.hats[i].termedParam.termEndDateTs),
                        uint256(SALT)
                    ),
                    adminHatId,
                    params.hats[i]
                );
            } else {
                _createHatAndAccountAndMintAndStreams(
                    params.hatsProtocol,
                    params.registry,
                    topHatAccount,
                    params.hatsAccountImplementation,
                    adminHatId,
                    params.hats[i]
                );
            }

            unchecked {
                ++i;
            }
        }

        params.hatsProtocol.transferHat(topHatId, address(this), msg.sender);
    }

    /**
     * @notice Creates a new role hat and any streams on it.
     *
     * @notice This contract should be enabled a module on the Safe for which the role is to be created, and disabled after.
     *
     * @dev In order for the module to be able to create hats on behalf of the Safe, the Safe must first
     * transfer its top hat to this contract. This function transfers the top hat back to the Safe after
     * creating the role hat.
     *
     * @dev The function simply calls `_createHatAndAccountAndMintAndStreams` and then transfers the top hat back to the Safe.
     *
     * @dev Stream funds on Roles are targeted at the hat's smart account. In order to withdraw funds from the stream, the
     * hat's smart account must be the one call to `withdraw-` on the Sablier contract, setting the recipient arg to its wearer.
     *
     * @dev Role hat creation, minting, smart account creation and stream creation are handled here in order
     * to avoid a race condition where not more than one active proposal to create a new role can exist at a time.
     * See: https://github.com/decentdao/decent-interface/issues/2402
     */
    function createRoleHat(CreateRoleHatParams calldata params) external {
        _createHatAndAccountAndMintAndStreams(
            params.hatsProtocol,
            params.registry,
            params.topHatAccount,
            params.hatsAccountImplementation,
            params.adminHatId,
            params.hat
        );

        params.hatsProtocol.transferHat(
            params.topHatId,
            address(this),
            msg.sender
        );
    }

    /**
     * @notice Creates a new termed role hat and any streams on it.
     *
     * @notice This contract should be enabled a module on the Safe for which the role is to be created, and disable after.
     *
     * @dev In order for the module to be able to create hats on behalf of the Safe, the Safe must first
     * transfer its top hat to this contract. This function transfers the top hat back to the Safe after
     * creating the role hat.
     *
     * @dev The function simply calls `_createTermedHatAndAccountAndMintAndStreams` and then transfers the top hat back to the Safe.
     *
     * @dev Stream funds on Termed Roles are targeted directly at the nominated wearer.
     * The wearer should directly call `withdraw-` on the Sablier contract.
     *
     * @dev Termed Role hat creation, minting, and stream creation are handled here in order
     * to avoid a race condition where not more than one active proposal to create a new termed role can exist at a time.
     * See: https://github.com/decentdao/decent-interface/issues/2402
     */
    function createTermedRoleHat(
        CreateTermedRoleHatParams calldata params
    ) external {
        _createTermedHatAndAccountAndMintAndStreams(
            params.hatsProtocol,
            params.topHatAccount,
            params.hatsModuleFactory.createHatsModule(
                params.hatsElectionEligibilityImplementation,
                params.hatsProtocol.getNextId(params.adminHatId),
                abi.encode(params.topHatId, uint256(0)),
                abi.encode(params.hat.termedParam.termEndDateTs),
                uint256(SALT)
            ),
            params.adminHatId,
            params.hat
        );

        params.hatsProtocol.transferHat(
            params.topHatId,
            address(this),
            msg.sender
        );
    }

    /* /////////////////////////////////////////////////////////////////////////////
                        INTERAL FUNCTIONS
    ///////////////////////////////////////////////////////////////////////////// */

    function _declareSafeHatTree(
        address _keyValuePairs,
        uint256 topHatId
    ) internal {
        string[] memory keys = new string[](1);
        string[] memory values = new string[](1);
        keys[0] = "topHatId";
        values[0] = Strings.toString(topHatId);

        IAvatar(msg.sender).execTransactionFromModule(
            _keyValuePairs,
            0,
            abi.encodeWithSignature(
                "updateValues(string[],string[])",
                keys,
                values
            ),
            Enum.Operation.Call
        );
    }

    function _createTopHatAndAccount(
        IHats _hatsProtocol,
        string memory _topHatDetails,
        string memory _topHatImageURI,
        IERC6551Registry _registry,
        address _hatsAccountImplementation
    ) internal returns (uint256 topHatId, address topHatAccount) {
        topHatId = _hatsProtocol.mintTopHat(
            address(this),
            _topHatDetails,
            _topHatImageURI
        );

        topHatAccount = _registry.createAccount(
            _hatsAccountImplementation,
            SALT,
            block.chainid,
            address(_hatsProtocol),
            topHatId
        );
    }

    function _createHatAndAccountAndMintAndStreams(
        IHats hatsProtocol,
        IERC6551Registry registry,
        address topHatAccount,
        address hatsAccountImplementation,
        uint256 adminHatId,
        Hat calldata hat
    ) internal returns (uint256 hatId, address accountAddress) {
        hatId = hatsProtocol.createHat(
            adminHatId,
            hat.details,
            hat.maxSupply,
            topHatAccount,
            topHatAccount,
            hat.isMutable,
            hat.imageURI
        );

        accountAddress = registry.createAccount(
            hatsAccountImplementation,
            SALT,
            block.chainid,
            address(hatsProtocol),
            hatId
        );

        hatsProtocol.mintHat(hatId, hat.wearer);

        for (uint256 i = 0; i < hat.sablierParams.length; ) {
            _createSablierStream(hat.sablierParams[i], accountAddress);
            unchecked {
                ++i;
            }
        }
    }

    function _createTermedHatAndAccountAndMintAndStreams(
        IHats hatsProtocol,
        address topHatAccount,
        address eligibilityAddress,
        uint256 adminHatId,
        Hat calldata hat
    ) internal {
        uint256 hatId = hatsProtocol.createHat(
            adminHatId,
            hat.details,
            hat.maxSupply,
            eligibilityAddress,
            topHatAccount,
            hat.isMutable,
            hat.imageURI
        );

        address[] memory nominatedWearers = new address[](1);
        nominatedWearers[0] = hat.termedParam.nominatedWearer;
        IHatsElectionEligibility(eligibilityAddress).elect(
            hat.termedParam.termEndDateTs,
            nominatedWearers
        );

        hatsProtocol.mintHat(hatId, hat.termedParam.nominatedWearer);

        for (uint256 i = 0; i < hat.sablierParams.length; ) {
            _createSablierStream(
                hat.sablierParams[i],
                hat.termedParam.nominatedWearer
            );
            unchecked {
                ++i;
            }
        }
    }

    function _createAdminHatAndAccount(
        IHats hatsProtocol,
        IERC6551Registry registry,
        ModuleProxyFactory moduleProxyFactory,
        address decentAutonomousAdminMasterCopy,
        address hatsAccountImplementation,
        address topHatAccount,
        uint256 topHatId,
        Hat calldata hat
    ) internal returns (uint256 adminHatId, address accountAddress) {
        adminHatId = hatsProtocol.createHat(
            topHatId,
            hat.details,
            hat.maxSupply,
            topHatAccount,
            topHatAccount,
            hat.isMutable,
            hat.imageURI
        );

        accountAddress = registry.createAccount(
            hatsAccountImplementation,
            SALT,
            block.chainid,
            address(hatsProtocol),
            adminHatId
        );

        hatsProtocol.mintHat(
            adminHatId,
            moduleProxyFactory.deployModule(
                decentAutonomousAdminMasterCopy,
                abi.encodeWithSignature("setUp(bytes)", bytes("")),
                uint256(keccak256(abi.encodePacked(SALT, adminHatId)))
            )
        );
    }

    function _createSablierStream(
        SablierStreamParams memory sablierParams,
        address recipient
    ) internal {
        // Approve tokens for Sablier
        IAvatar(msg.sender).execTransactionFromModule(
            sablierParams.asset,
            0,
            abi.encodeWithSignature(
                "approve(address,uint256)",
                sablierParams.sablier,
                sablierParams.totalAmount
            ),
            Enum.Operation.Call
        );

        LockupLinear.CreateWithTimestamps memory params = LockupLinear
            .CreateWithTimestamps({
                sender: sablierParams.sender,
                recipient: recipient,
                totalAmount: sablierParams.totalAmount,
                asset: IERC20(sablierParams.asset),
                cancelable: sablierParams.cancelable,
                transferable: sablierParams.transferable,
                timestamps: sablierParams.timestamps,
                broker: sablierParams.broker
            });

        // Proxy the Sablier call through IAvatar
        IAvatar(msg.sender).execTransactionFromModule(
            address(sablierParams.sablier),
            0,
            abi.encodeWithSignature(
                "createWithTimestamps((address,address,uint128,address,bool,bool,(uint40,uint40,uint40),(address,uint256)))",
                params
            ),
            Enum.Operation.Call
        );
    }
}
