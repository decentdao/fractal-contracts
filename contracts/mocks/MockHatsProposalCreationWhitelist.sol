// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../deployables/strategies/HatsProposalCreationWhitelistV1.sol";

contract MockHatsProposalCreationWhitelist is HatsProposalCreationWhitelistV1 {
    function setUp(bytes memory initializeParams) public override initializer {
        __Ownable_init(msg.sender);
        super.setUp(initializeParams);
    }
}
