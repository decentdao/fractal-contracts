// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IHatsModuleFactory} from "../interfaces/hats/full/IHatsModuleFactory.sol";
import {MockHatsElectionsEligibility} from "./MockHatsElectionEligibility.sol";

contract MockHatsModuleFactory is IHatsModuleFactory {
    function createHatsModule(
        address,
        uint256,
        bytes calldata,
        bytes calldata,
        uint256
    ) external override returns (address _instance) {
        // Deploy a new instance of MockHatsElectionEligibility
        MockHatsElectionsEligibility newModule = new MockHatsElectionsEligibility();
        _instance = address(newModule);
    }

    function getHatsModuleAddress(
        address _implementation,
        uint256 _hatId,
        bytes calldata _otherImmutableArgs,
        uint256 _saltNonce
    ) external view returns (address) {}

    function HATS() external view override returns (address) {}

    function version() external view override returns (string memory) {}

    function batchCreateHatsModule(
        address[] calldata _implementations,
        uint256[] calldata _hatIds,
        bytes[] calldata _otherImmutableArgsArray,
        bytes[] calldata _initDataArray,
        uint256[] calldata _saltNonces
    ) external override returns (bool success) {}

    function deployed(
        address _implementation,
        uint256 _hatId,
        bytes calldata _otherImmutableArgs,
        uint256 _saltNonce
    ) external view override returns (bool) {}
}
