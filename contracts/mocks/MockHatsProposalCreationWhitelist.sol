// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.28;

import "../deployables/strategies/HatsProposalCreationWhitelistV1.sol";

contract MockHatsProposalCreationWhitelist is HatsProposalCreationWhitelistV1 {
    function setUp(bytes memory initializeParams) public override initializer {
        __Ownable_init(msg.sender);
        super.setUp(initializeParams);
    }

    function getVersion() external pure override returns (uint16) {
        return 1;
    }
}
