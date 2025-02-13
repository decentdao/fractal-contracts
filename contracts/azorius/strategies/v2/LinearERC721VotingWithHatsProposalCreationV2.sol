// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {LinearERC721VotingWithHatsProposalCreation} from "../LinearERC721VotingWithHatsProposalCreation.sol";
import {IVersion} from "../../interfaces/IVersion.sol";

/**
 * An [Azorius](./Azorius.md) [BaseStrategy](./BaseStrategy.md) implementation that
 * enables linear (i.e. 1 to 1) ERC721 based token voting, with proposal creation
 * restricted to users wearing whitelisted Hats.
 */
contract LinearERC721VotingWithHatsProposalCreationV2 is
    LinearERC721VotingWithHatsProposalCreation,
    IVersion
{
    /** @inheritdoc IVersion*/
    function getVersion() external pure override returns (uint16) {
        // Although this function is implemented by parent class, we want them to have independent versionings
        // This should be incremented whenever the contract is modified
        return 2;
    }
}
