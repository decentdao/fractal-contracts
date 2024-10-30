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

contract DecentHatsUtils {
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

    function _createEligibilityModule(
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

    function _processSablierStreams(
        SablierStreamParams[] memory streamParams,
        address streamRecipient
    ) internal {
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
