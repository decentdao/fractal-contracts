// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IOwnershipV1} from "../interfaces/decent/IOwnershipV1.sol";

contract MockSmartAccount is IOwnershipV1 {
    address public owner;

    constructor(address _owner) {
        owner = _owner;
    }
}
