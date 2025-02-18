// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.19;

import {LinearERC721VotingExtensible} from "../LinearERC721VotingExtensible.sol";
import {IVersion} from "../../../interfaces/IVersion.sol";
import {ERC4337VoterSupport} from "./ERC4337VoterSupport.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IBaseStrategy} from "../../interfaces/IBaseStrategy.sol";
import {IERC721VotingStrategy} from "../../interfaces/IERC721VotingStrategy.sol";

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
contract LinearERC721VotingV2 is
    LinearERC721VotingExtensible,
    IVersion,
    ERC4337VoterSupport,
    ERC165
{
    /** @inheritdoc IVersion*/
    function getVersion() external pure virtual returns (uint16) {
        // This should be incremented whenever the contract is modified
        return 2;
    }

    /** @inheritdoc LinearERC721VotingExtensible*/
    function vote(
        uint32 _proposalId,
        uint8 _voteType,
        address[] memory _tokenAddresses,
        uint256[] memory _tokenIds
    ) external virtual override {
        if (_tokenAddresses.length != _tokenIds.length) revert InvalidParams();
        _vote(
            _proposalId,
            _voter(msg.sender),
            _voteType,
            _tokenAddresses,
            _tokenIds
        );
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IVersion).interfaceId ||
            interfaceId == type(IBaseStrategy).interfaceId ||
            interfaceId == type(IERC721VotingStrategy).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
