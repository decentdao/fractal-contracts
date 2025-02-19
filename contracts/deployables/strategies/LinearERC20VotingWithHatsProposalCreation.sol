// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.28;

import {LinearERC20Voting} from "./LinearERC20Voting.sol";
import {HatsProposalCreationWhitelistV1} from "./HatsProposalCreationWhitelistV1.sol";
import {IHats} from "../../interfaces/hats/IHats.sol";

/**
 * An [Azorius](./Azorius.md) [BaseStrategy](./BaseStrategy.md) implementation that
 * enables linear (i.e. 1 to 1) ERC20 based token voting, with proposal creation
 * restricted to users wearing whitelisted Hats.
 */
contract LinearERC20VotingWithHatsProposalCreation is
    HatsProposalCreationWhitelistV1,
    LinearERC20Voting
{
    /**
     * Sets up the contract with its initial parameters.
     *
     * @param initializeParams encoded initialization parameters: `address _owner`,
     * `address _governanceToken`, `address _azoriusModule`, `uint32 _votingPeriod`,
     * `uint256 _quorumNumerator`, `uint256 _basisNumerator`, `address _hatsContract`,
     * `uint256[] _initialWhitelistedHats`
     */
    function setUp(
        bytes memory initializeParams
    ) public override(HatsProposalCreationWhitelistV1, LinearERC20Voting) {
        (
            address _owner,
            address _governanceToken,
            address _azoriusModule,
            uint32 _votingPeriod,
            uint256 _quorumNumerator,
            uint256 _basisNumerator,
            address _hatsContract,
            uint256[] memory _initialWhitelistedHats
        ) = abi.decode(
                initializeParams,
                (
                    address,
                    address,
                    address,
                    uint32,
                    uint256,
                    uint256,
                    address,
                    uint256[]
                )
            );

        LinearERC20Voting.setUp(
            abi.encode(
                _owner,
                _governanceToken,
                _azoriusModule,
                _votingPeriod,
                0, // requiredProposerWeight is zero because we only care about the hat check
                _quorumNumerator,
                _basisNumerator
            )
        );

        HatsProposalCreationWhitelistV1.setUp(
            abi.encode(_hatsContract, _initialWhitelistedHats)
        );
    }

    /** @inheritdoc HatsProposalCreationWhitelistV1*/
    function isProposer(
        address _address
    )
        public
        view
        override(HatsProposalCreationWhitelistV1, LinearERC20Voting)
        returns (bool)
    {
        return HatsProposalCreationWhitelistV1.isProposer(_address);
    }
}
