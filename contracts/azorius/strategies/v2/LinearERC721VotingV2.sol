// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.19;

import {LinearERC721VotingExtensible} from "../LinearERC721VotingExtensible.sol";
import {IVersion} from "../../interfaces/IVersion.sol";

/**
 * An Azorius strategy that allows multiple ERC721 tokens to be registered as governance tokens,
 * each with their own voting weight.
 *
 * This is slightly different from ERC-20 voting, since there is no way to snapshot ERC721 holdings.
 * Each ERC721 id can vote once, reguardless of what address held it when a proposal was created.
 *
 * Also, this uses "quorumThreshold" rather than LinearERC20Voting's quorumPercent, because the
 * total supply of NFTs is not knowable within the IERC721 interface.  This is similar to a multisig
 * "total signers" required, rather than a percentage of the tokens.
 */
contract LinearERC721VotingV2 is LinearERC721VotingExtensible, IVersion {
    /** @inheritdoc IVersion*/
    function getVersion() external pure virtual returns (uint16) {
        // This should be incremented whenever the contract is modified
        return 2;
    }
}
