// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC4337VoterSupport} from "../deployables/strategies/ERC4337VoterSupport.sol";

contract MockERC4337VoterSupport is ERC4337VoterSupport {
    // Expose the internal _voter function for testing
    function voter(address _msgSender) external view returns (address) {
        return _voter(_msgSender);
    }
}
