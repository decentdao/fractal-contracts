// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import "./interfaces/IAzorius.sol";
import "./interfaces/IBaseStrategy.sol";
import "@gnosis.pm/zodiac/contracts/factory/FactoryFriendly.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title BaseStrategy - the base abstract contract for all voting strategies in Azorius.
 */
abstract contract BaseStrategy is OwnableUpgradeable, FactoryFriendly, IBaseStrategy {

    event AzoriusSet(address indexed azoriusModule);
    event StrategySetUp(address indexed azoriusModule, address indexed owner);

    IAzorius public azoriusModule;

    /**
     * Ensures that only the Azorius contract that pertains to this BaseStrategy
     * can call functions on it.
     */
    modifier onlyAzorius() {
        require(
            msg.sender == address(azoriusModule),
            "Only callable by Azorius module"
        );
        _;
    }

    /// @inheritdoc IBaseStrategy
    function setAzorius(address _azoriusModule) external onlyOwner {
        azoriusModule = IAzorius(_azoriusModule);
        emit AzoriusSet(_azoriusModule);
    }

    /**
     * Sets the address of the Azorius module contract.
     *
     * @param _azoriusModule address of the Azorius module
     */
    function _setAzorius(address _azoriusModule) internal {
        azoriusModule = IAzorius(_azoriusModule);
        emit AzoriusSet(_azoriusModule);
    }

    /// @inheritdoc IBaseStrategy
    function initializeProposal(bytes memory _data) external virtual;

    /// @inheritdoc IBaseStrategy
    function isPassed(uint256 _proposalId) external view virtual returns (bool);

    /// @inheritdoc IBaseStrategy
    function isProposer(address _address) external view virtual returns (bool);

    /// @inheritdoc IBaseStrategy
    function votingEndBlock(uint256 _proposalId) external view virtual returns (uint256);
}