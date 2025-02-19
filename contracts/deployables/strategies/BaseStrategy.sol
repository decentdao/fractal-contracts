// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.28;

import {IAzoriusV1} from "../../interfaces/decent/deployables/IAzoriusV1.sol";
import {IBaseStrategyV1} from "../../interfaces/decent/deployables/IBaseStrategyV1.sol";
import {FactoryFriendly} from "@gnosis-guild/zodiac/contracts/factory/FactoryFriendly.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * The base abstract contract for all voting strategies in Azorius.
 */
abstract contract BaseStrategy is
    OwnableUpgradeable,
    FactoryFriendly,
    IBaseStrategyV1
{
    event AzoriusSet(address indexed azoriusModule);
    event StrategySetUp(address indexed azoriusModule, address indexed owner);

    error OnlyAzorius();

    IAzoriusV1 public azoriusModule;

    /**
     * Ensures that only the [Azorius](./Azorius.md) contract that pertains to this
     * [BaseStrategy](./BaseStrategy.md) can call functions on it.
     */
    modifier onlyAzorius() {
        if (msg.sender != address(azoriusModule)) revert OnlyAzorius();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    /** @inheritdoc IBaseStrategyV1*/
    function setAzorius(address _azoriusModule) external onlyOwner {
        azoriusModule = IAzoriusV1(_azoriusModule);
        emit AzoriusSet(_azoriusModule);
    }

    /** @inheritdoc IBaseStrategyV1*/
    function initializeProposal(bytes memory _data) external virtual;

    /** @inheritdoc IBaseStrategyV1*/
    function isPassed(uint32 _proposalId) external view virtual returns (bool);

    /** @inheritdoc IBaseStrategyV1*/
    function isProposer(address _address) external view virtual returns (bool);

    /** @inheritdoc IBaseStrategyV1*/
    function votingEndBlock(
        uint32 _proposalId
    ) external view virtual returns (uint32);

    /**
     * Sets the address of the [Azorius](Azorius.md) module contract.
     *
     * @param _azoriusModule address of the Azorius module
     */
    function _setAzorius(address _azoriusModule) internal {
        azoriusModule = IAzoriusV1(_azoriusModule);
        emit AzoriusSet(_azoriusModule);
    }
}
