// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.28;

import {IVersion} from "../../interfaces/decent/deployables/IVersion.sol";
import {LinearERC721VotingV1} from "./LinearERC721VotingV1.sol";
import {HatsProposalCreationWhitelistV1} from "./HatsProposalCreationWhitelistV1.sol";

/**
 * An [Azorius](./Azorius.md) [BaseStrategy](./BaseStrategy.md) implementation that
 * enables linear (i.e. 1 to 1) ERC721 based token voting, with proposal creation
 * restricted to users wearing whitelisted Hats.
 */
contract LinearERC721VotingWithHatsProposalCreationV1 is
    HatsProposalCreationWhitelistV1,
    LinearERC721VotingV1
{
    /**
     * Sets up the contract with its initial parameters.
     *
     * @param initializeParams encoded initialization parameters: `address _owner`,
     * `address[] memory _tokens`, `uint256[] memory _weights`, `address _azoriusModule`,
     * `uint32 _votingPeriod`, `uint256 _quorumThreshold`, `uint256 _basisNumerator`,
     * `address _hatsContract`, `uint256[] _initialWhitelistedHats`
     */
    function setUp(
        bytes memory initializeParams
    ) public override(HatsProposalCreationWhitelistV1, LinearERC721VotingV1) {
        (
            address _owner,
            address[] memory _tokens,
            uint256[] memory _weights,
            address _azoriusModule,
            uint32 _votingPeriod,
            uint256 _quorumThreshold,
            uint256 _basisNumerator,
            address _hatsContract,
            uint256[] memory _initialWhitelistedHats
        ) = abi.decode(
                initializeParams,
                (
                    address,
                    address[],
                    uint256[],
                    address,
                    uint32,
                    uint256,
                    uint256,
                    address,
                    uint256[]
                )
            );

        LinearERC721VotingV1.setUp(
            abi.encode(
                _owner,
                _tokens,
                _weights,
                _azoriusModule,
                _votingPeriod,
                _quorumThreshold,
                0, // _proposerThreshold is zero because we only care about the hat check
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
        override(HatsProposalCreationWhitelistV1, LinearERC721VotingV1)
        returns (bool)
    {
        return HatsProposalCreationWhitelistV1.isProposer(_address);
    }

    /// @inheritdoc IVersion
    function getVersion()
        external
        pure
        virtual
        override(HatsProposalCreationWhitelistV1, LinearERC721VotingV1)
        returns (uint16)
    {
        return 1;
    }
}
