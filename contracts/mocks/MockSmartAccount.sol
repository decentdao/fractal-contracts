// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IOwnership} from "../interfaces/decent/deployables/IOwnership.sol";

contract MockSmartAccount is IOwnership {
    address public owner;

    constructor(address _owner) {
        owner = _owner;
    }
}
