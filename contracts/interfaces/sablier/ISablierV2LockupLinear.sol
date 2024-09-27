// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LockupLinear} from "./LockupLinear.sol";
import {ISablierV2Lockup} from "./ISablierV2Lockup.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISablierV2LockupLinear is ISablierV2Lockup {
    function createWithTimestamps(
        LockupLinear.CreateWithTimestamps calldata params
    ) external returns (uint256 streamId);
}
