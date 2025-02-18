// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../deployables/strategies/HatsProposalCreationWhitelist.sol";

contract MockHatsProposalCreationWhitelist is HatsProposalCreationWhitelist {
    function setUp(bytes memory initializeParams) public override initializer {
        __Ownable_init(msg.sender);
        super.setUp(initializeParams);
    }
}
