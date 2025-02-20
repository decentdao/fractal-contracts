// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.28;

import {IOwnershipV1} from "../../interfaces/decent/deployables/IOwnershipV1.sol";

abstract contract ERC4337VoterSupportV1 {
    /**
     * Returns the address of the voter which owns the voting weight
     * @param _msgSender address of the sender. It can be the wallet address, or the smart account address with EOA as owner
     * @return address of the voter
     */
    function _voter(
        address _msgSender
    ) internal view virtual returns (address) {
        // First check if the address has code (is a contract)
        uint256 size;
        assembly {
            size := extcodesize(_msgSender)
        }

        // If it's an EOA (no code), return the address directly
        if (size == 0) {
            return _msgSender;
        }

        // If it's a contract, try to get its owner
        try IOwnershipV1(_msgSender).owner() returns (address _value) {
            return _value;
        } catch {
            return _msgSender;
        }
    }
}
