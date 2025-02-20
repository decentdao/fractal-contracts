// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC4337VoterSupportV1} from "../deployables/strategies/ERC4337VoterSupportV1.sol";

contract MockERC4337VoterSupport is ERC4337VoterSupportV1 {
    // Expose the internal _voter function for testing
    function voter(address _msgSender) external view returns (address) {
        return _voter(_msgSender);
    }

    function getVersion() external pure override returns (uint16) {
        return 1;
    }
}
