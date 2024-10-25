// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {Enum} from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import {IAvatar} from "@gnosis.pm/zodiac/contracts/interfaces/IAvatar.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC6551Registry} from "./interfaces/IERC6551Registry.sol";
import {IHats} from "./interfaces/hats/IHats.sol";
import {ISablierV2LockupLinear} from "./interfaces/sablier/ISablierV2LockupLinear.sol";
import {LockupLinear} from "./interfaces/sablier/LockupLinear.sol";

contract DecentHats_0_1_0 {
    string public constant NAME = "DecentHats_0_1_0";

    struct SablierStreamParams {
        ISablierV2LockupLinear sablier;
        address sender;
        uint128 totalAmount;
        address asset;
        bool cancelable;
        bool transferable;
        LockupLinear.Timestamps timestamps;
        LockupLinear.Broker broker;
    }

    struct Hat {
        uint32 maxSupply;
        string details;
        string imageURI;
        bool isMutable;
        address wearer;
        SablierStreamParams[] sablierParams; // Optional Sablier stream parameters
    }

    struct CreateTreeParams {
        IHats hatsProtocol;
        address hatsAccountImplementation;
        IERC6551Registry registry;
        address keyValuePairs;
        string topHatDetails;
        string topHatImageURI;
        Hat adminHat;
        Hat[] hats;
    }

    function getSalt() public pure returns (bytes32 salt) {
        return
            0x5d0e6ce4fd951366cc55da93f6e79d8b81483109d79676a04bcc2bed6a4b5072;
    }

    function declareSafeHatTree(
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

    function createHat(
        IHats _hatsProtocol,
        uint256 adminHatId,
        Hat memory _hat,
        address topHatAccount
    ) internal returns (uint256) {
        return
            _hatsProtocol.createHat(
                adminHatId,
                _hat.details,
                _hat.maxSupply,
                topHatAccount,
                topHatAccount,
                _hat.isMutable,
                _hat.imageURI
            );
    }

    function createAccount(
        IERC6551Registry _registry,
        address _hatsAccountImplementation,
        bytes32 salt,
        address protocolAddress,
        uint256 hatId
    ) internal returns (address) {
        return
            _registry.createAccount(
                _hatsAccountImplementation,
                salt,
                block.chainid,
                protocolAddress,
                hatId
            );
    }

    function createTopHatAndAccount(
        IHats _hatsProtocol,
        string memory _topHatDetails,
        string memory _topHatImageURI,
        IERC6551Registry _registry,
        address _hatsAccountImplementation,
        bytes32 salt
    ) internal returns (uint256 topHatId, address topHatAccount) {
        topHatId = _hatsProtocol.mintTopHat(
            address(this),
            _topHatDetails,
            _topHatImageURI
        );

        topHatAccount = createAccount(
            _registry,
            _hatsAccountImplementation,
            salt,
            address(_hatsProtocol),
            topHatId
        );
    }

    function createHatAndAccountAndMintAndStreams(
        IHats hatsProtocol,
        uint256 adminHatId,
        Hat calldata hat,
        address topHatAccount,
        IERC6551Registry registry,
        address hatsAccountImplementation,
        bytes32 salt
    ) internal returns (uint256 hatId, address accountAddress) {
        hatId = createHat(hatsProtocol, adminHatId, hat, topHatAccount);

        accountAddress = createAccount(
            registry,
            hatsAccountImplementation,
            salt,
            address(hatsProtocol),
            hatId
        );

        if (hat.wearer != address(0)) {
            hatsProtocol.mintHat(hatId, hat.wearer);
        }

        for (uint256 i = 0; i < hat.sablierParams.length; ) {
            SablierStreamParams memory sablierParams = hat.sablierParams[i];

            // Approve tokens for Sablier
            IAvatar(msg.sender).execTransactionFromModule(
                sablierParams.asset,
                0,
                abi.encodeWithSignature(
                    "approve(address,uint256)",
                    address(sablierParams.sablier),
                    sablierParams.totalAmount
                ),
                Enum.Operation.Call
            );

            LockupLinear.CreateWithTimestamps memory params = LockupLinear
                .CreateWithTimestamps({
                    sender: sablierParams.sender,
                    recipient: accountAddress,
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

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Creates a new role hat and any streams on it.
     *
     * @notice This contract should be enabled a module on the Safe for which the role is to be created, and disabled after.
     *
     * @dev In order for the module to be able to create hats on behalf of the Safe, the Safe must first transfer its top hat to this contract. This function transfers the top hat back to the Safe after
     * creating the role hat.
     *
     * @dev The function simply calls `createHatAndAccountAndMintAndStreams` and then transfers the top hat back to the Safe.
     *
     * @dev Role hat creation, minting, smart account creation and stream creation are handled here in order
     * to avoid a race condition where not more than one active proposal to create a new role can exist at a time.
     * See: https://github.com/decentdao/decent-interface/issues/2402
     */
    function createRoleHat(
        IHats hatsProtocol,
        uint256 adminHatId,
        Hat calldata hat,
        uint256 topHatId,
        address topHatAccount,
        IERC6551Registry registry,
        address hatsAccountImplementation,
        bytes32 salt
    ) public returns (uint256 hatId, address accountAddress) {
        (hatId, accountAddress) = createHatAndAccountAndMintAndStreams(
            hatsProtocol,
            adminHatId,
            hat,
            topHatAccount,
            registry,
            hatsAccountImplementation,
            salt
        );

        hatsProtocol.transferHat(topHatId, address(this), msg.sender);
    }

    /**
     * @notice For a safe without any roles previously created on it, this function should be called. It sets up the
     * top hat and admin hat, as well as any other hats and their streams that are provided.
     *
     * @notice This contract should be enabled a module on the Safe for which the role(s) are to be created, and disabled after.
     *
     * @dev In order for a Safe to seamlessly create roles even if it has never previously created a role and thus has
     * no hat tree, we defer the creation of the hat tree and its setup to this contract. This way, in a single tx block,
     * the resulting topHatId of the newly created hat can be used to create an admin hat and any other hats needed.
     * We also make use of `KeyValuePairs` to associate the topHatId with the Safe.
     */
    function createAndDeclareTree(CreateTreeParams calldata params) public {
        bytes32 salt = getSalt();

        (uint256 topHatId, address topHatAccount) = createTopHatAndAccount(
            params.hatsProtocol,
            params.topHatDetails,
            params.topHatImageURI,
            params.registry,
            params.hatsAccountImplementation,
            salt
        );

        declareSafeHatTree(params.keyValuePairs, topHatId);

        (uint256 adminHatId, ) = createHatAndAccountAndMintAndStreams(
            params.hatsProtocol,
            topHatId,
            params.adminHat,
            topHatAccount,
            params.registry,
            params.hatsAccountImplementation,
            salt
        );

        for (uint256 i = 0; i < params.hats.length; ) {
            createHatAndAccountAndMintAndStreams(
                params.hatsProtocol,
                adminHatId,
                params.hats[i],
                topHatAccount,
                params.registry,
                params.hatsAccountImplementation,
                salt
            );

            unchecked {
                ++i;
            }
        }

        params.hatsProtocol.transferHat(topHatId, address(this), msg.sender);
    }
}
