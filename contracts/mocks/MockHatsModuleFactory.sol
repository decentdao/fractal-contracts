// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IHatsModuleFactory} from "../interfaces/IHatModuleFactory.sol";

contract MockHatsModuleFactory is IHatsModuleFactory {
    function createHatsModule(
        address _implementation,
        uint256 _hatId,
        bytes calldata _otherImmutableArgs,
        bytes calldata _initData,
        uint256 _saltNonce
    ) external pure returns (address _instance) {
        // Silence unused variable warnings
        _implementation;
        _hatId;
        _otherImmutableArgs;
        _initData;
        _saltNonce;
        return address(0);
    }

    function getHatsModuleAddress(
        address _implementation,
        uint256 _hatId,
        bytes calldata _otherImmutableArgs,
        uint256 _saltNonce
    ) external pure returns (address) {
        // Silence unused variable warnings
        _implementation;
        _hatId;
        _otherImmutableArgs;
        _saltNonce;
        return address(0);
    }
}
