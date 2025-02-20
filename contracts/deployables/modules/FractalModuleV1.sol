// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.28;

import {IVersion} from "../../interfaces/decent/deployables/IVersion.sol";
import {IFractalModuleV1} from "../../interfaces/decent/deployables/IFractalModuleV1.sol";
import {GuardableModule, Enum} from "@gnosis-guild/zodiac/contracts/core/GuardableModule.sol";

/**
 * Implementation of [IFractalModule](./interfaces/IFractalModule.md).
 *
 * A Safe module contract that allows for a "parent-child" DAO relationship.
 *
 * Adding the module allows for a designated set of addresses to execute
 * transactions on the Safe, which in our implementation is the set of parent
 * DAOs.
 */
contract FractalModuleV1 is IVersion, IFractalModuleV1, GuardableModule {
    /** Mapping of whether an address is a controller (typically a parentDAO). */
    mapping(address => bool) public controllers;

    event ControllersAdded(address[] controllers);
    event ControllersRemoved(address[] controllers);

    error Unauthorized();
    error TxFailed();

    /** Allows only authorized controllers to execute transactions on the Safe. */
    modifier onlyAuthorized() {
        if (owner() != msg.sender && !controllers[msg.sender])
            revert Unauthorized();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    /**
     * Initialize function, will be triggered when a new instance is deployed.
     *
     * @param initializeParams encoded initialization parameters: `address _owner`,
     * `address _avatar`, `address _target`, `address[] memory _controllers`
     */
    function setUp(bytes memory initializeParams) public override initializer {
        (
            address _owner, // controlling DAO
            address _avatar,
            address _target,
            address[] memory _controllers // authorized controllers
        ) = abi.decode(
                initializeParams,
                (address, address, address, address[])
            );

        __Ownable_init(msg.sender);
        setAvatar(_avatar);
        setTarget(_target);
        addControllers(_controllers);
        transferOwnership(_owner);
    }

    /** @inheritdoc IFractalModuleV1*/
    function removeControllers(
        address[] memory _controllers
    ) external onlyOwner {
        uint256 controllersLength = _controllers.length;
        for (uint256 i; i < controllersLength; ) {
            controllers[_controllers[i]] = false;
            unchecked {
                ++i;
            }
        }
        emit ControllersRemoved(_controllers);
    }

    /** @inheritdoc IFractalModuleV1*/
    function execTx(bytes memory execTxData) public onlyAuthorized {
        (
            address _target,
            uint256 _value,
            bytes memory _data,
            Enum.Operation _operation
        ) = abi.decode(execTxData, (address, uint256, bytes, Enum.Operation));
        if (!exec(_target, _value, _data, _operation)) revert TxFailed();
    }

    /** @inheritdoc IFractalModuleV1*/
    function addControllers(address[] memory _controllers) public onlyOwner {
        uint256 controllersLength = _controllers.length;
        for (uint256 i; i < controllersLength; ) {
            controllers[_controllers[i]] = true;
            unchecked {
                ++i;
            }
        }
        emit ControllersAdded(_controllers);
    }

    /// @inheritdoc IVersion
    function getVersion() external pure virtual override returns (uint16) {
        return 1;
    }
}
