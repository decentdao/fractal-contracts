// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.19;

import {IOwnership} from "../../../interfaces/IOwnership.sol";

abstract contract ERC4337VoterSupport {
    /**
     * Returns the address of the voter which owns the voting weight
     * @param _msgSender address of the sender. It can be the wallet address, or the smart account address with EOA as owner
     * @return address of the voter
     */
    function _voter(address _msgSender) internal virtual returns (address) {
        try IOwnership(_msgSender).owner() returns (address _value) {
            return (_value);
        } catch {
            return _msgSender;
        }
    }
}
