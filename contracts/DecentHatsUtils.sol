// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Enum} from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import {IAvatar} from "@gnosis.pm/zodiac/contracts/interfaces/IAvatar.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC6551Registry} from "./interfaces/IERC6551Registry.sol";
import {IHats} from "./interfaces/hats/full/IHats.sol";
import {LockupLinear, Broker} from "./interfaces/sablier/full/types/DataTypes.sol";
import {IHatsModuleFactory} from "./interfaces/hats/full/IHatsModuleFactory.sol";
import {ISablierV2LockupLinear} from "./interfaces/sablier/ISablierV2LockupLinear.sol";

abstract contract DecentHatsUtils {
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

    struct HatParams {
        address wearer;
        string details;
        string imageURI;
        SablierStreamParams[] sablierStreamsParams;
        uint128 termEndDateTs; // If 0, this is an untermed Hat
        uint32 maxSupply;
        bool isMutable;
    }

    function _processHat(
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
        address eligibilityAddress = _createEligibilityModule(
            hatsProtocol,
            hatsModuleFactory,
            hatsElectionsEligibilityImplementation,
            topHatId,
            topHatAccount,
            adminHatId,
            hat.termEndDateTs
        );

        // Create and Mint the Role Hat
        uint256 hatId = _createAndMintHat(
            hatsProtocol,
            adminHatId,
            hat,
            eligibilityAddress,
            topHatAccount
        );

        // Get the stream recipient (based on termed or not)
        address streamRecipient = _setupStreamRecipient(
            registry,
            hatsAccountImplementation,
            address(hatsProtocol),
            hat.termEndDateTs,
            hat.wearer,
            hatId
        );

        // Create streams
        _processSablierStreams(hat.sablierStreamsParams, streamRecipient);
    }

    function _createEligibilityModule(
        IHats hatsProtocol,
        IHatsModuleFactory hatsModuleFactory,
        address hatsElectionsEligibilityImplementation,
        uint256 topHatId,
        address topHatAccount,
        uint256 adminHatId,
        uint128 termEndDateTs
    ) private returns (address) {
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

    function _createAndMintHat(
        IHats hatsProtocol,
        uint256 adminHatId,
        HatParams memory hat,
        address eligibilityAddress,
        address topHatAccount
    ) private returns (uint256) {
        uint256 hatId = hatsProtocol.getNextId(adminHatId);
        IAvatar(msg.sender).execTransactionFromModule(
            address(hatsProtocol),
            0,
            abi.encodeWithSignature(
                "createHat(uint256,string,uint32,address,address,bool,string)",
                adminHatId,
                hat.details,
                hat.maxSupply,
                eligibilityAddress,
                topHatAccount,
                hat.isMutable,
                hat.imageURI
            ),
            Enum.Operation.Call
        );

        // If the hat is termed, nominate the wearer as the eligible member
        if (hat.termEndDateTs != 0) {
            address[] memory nominatedWearers = new address[](1);
            nominatedWearers[0] = hat.wearer;

            IAvatar(msg.sender).execTransactionFromModule(
                eligibilityAddress,
                0,
                abi.encodeWithSignature(
                    "elect(uint128,address[])",
                    hat.termEndDateTs,
                    nominatedWearers
                ),
                Enum.Operation.Call
            );
        }

        IAvatar(msg.sender).execTransactionFromModule(
            address(hatsProtocol),
            0,
            abi.encodeWithSignature(
                "mintHat(uint256,address)",
                hatId,
                hat.wearer
            ),
            Enum.Operation.Call
        );
        return hatId;
    }

    // Exists to avoid stack too deep errors
    function _setupStreamRecipient(
        IERC6551Registry registry,
        address hatsAccountImplementation,
        address hatsProtocol,
        uint128 termEndDateTs,
        address wearer,
        uint256 hatId
    ) private returns (address) {
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

    function _processSablierStreams(
        SablierStreamParams[] memory streamParams,
        address streamRecipient
    ) private {
        for (uint256 i = 0; i < streamParams.length; ) {
            SablierStreamParams memory sablierStreamParams = streamParams[i];

            // Approve tokens for Sablier
            IAvatar(msg.sender).execTransactionFromModule(
                sablierStreamParams.asset,
                0,
                abi.encodeWithSignature(
                    "approve(address,uint256)",
                    sablierStreamParams.sablier,
                    sablierStreamParams.totalAmount
                ),
                Enum.Operation.Call
            );

            // Proxy the Sablier call through IAvatar
            IAvatar(msg.sender).execTransactionFromModule(
                address(sablierStreamParams.sablier),
                0,
                abi.encodeWithSignature(
                    "createWithTimestamps((address,address,uint128,address,bool,bool,(uint40,uint40,uint40),(address,uint256)))",
                    LockupLinear.CreateWithTimestamps({
                        sender: sablierStreamParams.sender,
                        recipient: streamRecipient,
                        totalAmount: sablierStreamParams.totalAmount,
                        asset: IERC20(sablierStreamParams.asset),
                        cancelable: sablierStreamParams.cancelable,
                        transferable: sablierStreamParams.transferable,
                        timestamps: sablierStreamParams.timestamps,
                        broker: sablierStreamParams.broker
                    })
                ),
                Enum.Operation.Call
            );

            unchecked {
                ++i;
            }
        }
    }
}
