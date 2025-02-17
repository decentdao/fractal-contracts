// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.19;

/**
 * Interface to get the owner of a smart account
 */
interface IOwnership {
    /**
     * Returns the owner address, could be EOA for regular voters, but could be DAO Safe or other smart contract
     *
     */
    function owner() external pure returns (address);
}

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
