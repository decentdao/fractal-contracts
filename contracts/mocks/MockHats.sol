// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IHats} from "../interfaces/hats/full/IHats.sol";
import {IHatsIdUtilities} from "../interfaces/hats/full/IHatsIdUtilities.sol";

/// @notice Minimalist and gas efficient standard ERC1155 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    event URI(string value, uint256 indexed id);

    /*//////////////////////////////////////////////////////////////
                             ERC1155 STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => mapping(uint256 => uint256)) internal _balanceOf;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                             METADATA LOGIC
    //////////////////////////////////////////////////////////////*/

    function uri(uint256 id) public view virtual returns (string memory);

    /*//////////////////////////////////////////////////////////////
                              ERC1155 LOGIC
    //////////////////////////////////////////////////////////////*/

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual {
        require(
            msg.sender == from || isApprovedForAll[from][msg.sender],
            "NOT_AUTHORIZED"
        );

        _balanceOf[from][id] -= amount;
        _balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(
                    msg.sender,
                    from,
                    id,
                    amount,
                    data
                ) == ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual {
        require(ids.length == amounts.length, "LENGTH_MISMATCH");

        require(
            msg.sender == from || isApprovedForAll[from][msg.sender],
            "NOT_AUTHORIZED"
        );

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 amount;

        for (uint256 i = 0; i < ids.length; ) {
            id = ids[i];
            amount = amounts[i];

            _balanceOf[from][id] -= amount;
            _balanceOf[to][id] += amount;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(
                    msg.sender,
                    from,
                    ids,
                    amounts,
                    data
                ) == ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function balanceOf(
        address owner,
        uint256 id
    ) public view virtual returns (uint256 balance) {
        balance = _balanceOf[owner][id];
    }

    function balanceOfBatch(
        address[] calldata owners,
        uint256[] calldata ids
    ) public view virtual returns (uint256[] memory balances) {
        require(owners.length == ids.length, "LENGTH_MISMATCH");

        balances = new uint256[](owners.length);

        // Unchecked because the only math done is incrementing
        // the array index counter which cannot possibly overflow.
        unchecked {
            for (uint256 i = 0; i < owners.length; ++i) {
                balances[i] = _balanceOf[owners[i]][ids[i]];
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0xd9b67a26 || // ERC165 Interface ID for ERC1155
            interfaceId == 0x0e89341c; // ERC165 Interface ID for ERC1155MetadataURI
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        _balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, address(0), to, id, amount);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(
                    msg.sender,
                    address(0),
                    id,
                    amount,
                    data
                ) == ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        uint256 idsLength = ids.length; // Saves MLOADs.

        require(idsLength == amounts.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < idsLength; ) {
            _balanceOf[to][ids[i]] += amounts[i];

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, address(0), to, ids, amounts);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(
                    msg.sender,
                    address(0),
                    ids,
                    amounts,
                    data
                ) == ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _batchBurn(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        uint256 idsLength = ids.length; // Saves MLOADs.

        require(idsLength == amounts.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < idsLength; ) {
            _balanceOf[from][ids[i]] -= amounts[i];

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, address(0), ids, amounts);
    }

    function _burn(address from, uint256 id, uint256 amount) internal virtual {
        _balanceOf[from][id] -= amount;

        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }
}

/// @notice A generic interface for a contract which properly accepts ERC1155 tokens.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}

/// @notice see HatsErrors.sol for description
error MaxLevelsReached();

/// @title Hats Id Utilities
/// @dev Functions for working with Hat Ids from Hats Protocol. Factored out of Hats.sol
/// for easier use by other contracts.
/// @author Haberdasher Labs
contract MockHatsIdUtilities is IHatsIdUtilities {
    /// @notice Mapping of tophats requesting to link to admin hats in other trees
    /// @dev Linkage only occurs if request is approved by the new admin
    mapping(uint32 => uint256) public linkedTreeRequests; // topHatDomain => requested new admin

    /// @notice Mapping of approved & linked tophats to admin hats in other trees, used for grafting one hats tree onto another
    /// @dev Trees can only be linked to another tree via their tophat
    mapping(uint32 => uint256) public linkedTreeAdmins; // topHatDomain => hatId

    /**
     * Hat Ids serve as addresses. A given Hat's Id represents its location in its
     * hat tree: its level, its admin, its admin's admin (etc, all the way up to the
     * tophat).
     *
     * The top level consists of 4 bytes and references all tophats.
     *
     * Each level below consists of 16 bits, and contains up to 65,536 child hats.
     *
     * A uint256 contains 4 bytes of space for tophat addresses, giving room for ((256 -
     * 32) / 16) = 14 levels of delegation, with the admin at each level having space for
     * 65,536 different child hats.
     *
     * A hat tree consists of a single tophat and has a max depth of 14 levels.
     */

    /// @dev Number of bits of address space for tophat ids, ie the tophat domain
    uint256 internal constant TOPHAT_ADDRESS_SPACE = 32;

    /// @dev Number of bits of address space for each level below the tophat
    uint256 internal constant LOWER_LEVEL_ADDRESS_SPACE = 16;

    /// @dev Maximum number of levels below the tophat, ie max tree depth
    ///      (256 - TOPHAT_ADDRESS_SPACE) / LOWER_LEVEL_ADDRESS_SPACE;
    uint256 internal constant MAX_LEVELS = 14;

    /// @notice Constructs a valid hat id for a new hat underneath a given admin
    /// @dev Reverts if the admin has already reached `MAX_LEVELS`
    /// @param _admin the id of the admin for the new hat
    /// @param _newHat the uint16 id of the new hat
    /// @return id The constructed hat id
    function buildHatId(
        uint256 _admin,
        uint16 _newHat
    ) public pure returns (uint256 id) {
        uint256 mask;
        for (uint256 i = 0; i < MAX_LEVELS; ) {
            unchecked {
                mask = uint256(
                    type(uint256).max >>
                        // should not overflow given known constants
                        (TOPHAT_ADDRESS_SPACE + (LOWER_LEVEL_ADDRESS_SPACE * i))
                );
            }
            if (_admin & mask == 0) {
                unchecked {
                    id =
                        _admin |
                        (uint256(_newHat) <<
                            // should not overflow given known constants
                            (LOWER_LEVEL_ADDRESS_SPACE * (MAX_LEVELS - 1 - i)));
                }
                return id;
            }

            // should not overflow based on < MAX_LEVELS stopping condition
            unchecked {
                ++i;
            }
        }

        // if _admin is already at MAX_LEVELS, child hats are not possible, so we revert
        revert MaxLevelsReached();
    }

    /// @notice Identifies the level a given hat in its hat tree
    /// @param _hatId the id of the hat in question
    /// @return level (0 to type(uint32).max)
    function getHatLevel(uint256 _hatId) public view returns (uint32 level) {
        // uint256 mask;
        // uint256 i;
        level = getLocalHatLevel(_hatId);

        uint256 treeAdmin = linkedTreeAdmins[getTopHatDomain(_hatId)];

        if (treeAdmin != 0) {
            level = 1 + level + getHatLevel(treeAdmin);
        }
    }

    /// @notice Identifies the level a given hat in its local hat tree
    /// @dev Similar to getHatLevel, but does not account for linked trees
    /// @param _hatId the id of the hat in question
    /// @return level The local level, from 0 to 14
    function getLocalHatLevel(
        uint256 _hatId
    ) public pure returns (uint32 level) {
        if (_hatId & uint256(type(uint224).max) == 0) return 0;
        if (_hatId & uint256(type(uint208).max) == 0) return 1;
        if (_hatId & uint256(type(uint192).max) == 0) return 2;
        if (_hatId & uint256(type(uint176).max) == 0) return 3;
        if (_hatId & uint256(type(uint160).max) == 0) return 4;
        if (_hatId & uint256(type(uint144).max) == 0) return 5;
        if (_hatId & uint256(type(uint128).max) == 0) return 6;
        if (_hatId & uint256(type(uint112).max) == 0) return 7;
        if (_hatId & uint256(type(uint96).max) == 0) return 8;
        if (_hatId & uint256(type(uint80).max) == 0) return 9;
        if (_hatId & uint256(type(uint64).max) == 0) return 10;
        if (_hatId & uint256(type(uint48).max) == 0) return 11;
        if (_hatId & uint256(type(uint32).max) == 0) return 12;
        if (_hatId & uint256(type(uint16).max) == 0) return 13;
        return 14;
    }

    /// @notice Checks whether a hat is a topHat
    /// @param _hatId The hat in question
    /// @return _isTopHat Whether the hat is a topHat
    function isTopHat(uint256 _hatId) public view returns (bool _isTopHat) {
        _isTopHat =
            isLocalTopHat(_hatId) &&
            linkedTreeAdmins[getTopHatDomain(_hatId)] == 0;
    }

    /// @notice Checks whether a hat is a topHat in its local hat tree
    /// @dev Similar to isTopHat, but does not account for linked trees
    /// @param _hatId The hat in question
    /// @return _isLocalTopHat Whether the hat is a topHat for its local tree
    function isLocalTopHat(
        uint256 _hatId
    ) public pure returns (bool _isLocalTopHat) {
        _isLocalTopHat = _hatId > 0 && uint224(_hatId) == 0;
    }

    function isValidHatId(
        uint256 _hatId
    ) public pure returns (bool validHatId) {
        // valid top hats are valid hats
        if (isLocalTopHat(_hatId)) return true;

        uint32 level = getLocalHatLevel(_hatId);
        uint256 admin;
        // for each subsequent level up the tree, check if the level is 0 and return false if so
        for (uint256 i = level - 1; i > 0; ) {
            // truncate to find the (truncated) admin at this level
            // we don't need to check _hatId's own level since getLocalHatLevel already ensures that its non-empty
            admin = _hatId >> (LOWER_LEVEL_ADDRESS_SPACE * (MAX_LEVELS - i));
            // if the lowest level of the truncated admin is empty, the hat id is invalid
            if (uint16(admin) == 0) return false;

            unchecked {
                --i;
            }
        }
        // if there are no empty levels, return true
        return true;
    }

    /// @notice Gets the hat id of the admin at a given level of a given hat
    /// @dev This function traverses trees by following the linkedTreeAdmin
    ///       pointer to a hat located in a different tree
    /// @param _hatId the id of the hat in question
    /// @param _level the admin level of interest
    /// @return admin The hat id of the resulting admin
    function getAdminAtLevel(
        uint256 _hatId,
        uint32 _level
    ) public view returns (uint256 admin) {
        uint256 linkedTreeAdmin = linkedTreeAdmins[getTopHatDomain(_hatId)];
        if (linkedTreeAdmin == 0)
            return admin = getAdminAtLocalLevel(_hatId, _level);

        uint32 localTopHatLevel = getHatLevel(getAdminAtLocalLevel(_hatId, 0));

        if (localTopHatLevel <= _level)
            return
                admin = getAdminAtLocalLevel(_hatId, _level - localTopHatLevel);

        return admin = getAdminAtLevel(linkedTreeAdmin, _level);
    }

    /// @notice Gets the hat id of the admin at a given level of a given hat
    ///         local to the tree containing the hat.
    /// @param _hatId the id of the hat in question
    /// @param _level the admin level of interest
    /// @return admin The hat id of the resulting admin
    function getAdminAtLocalLevel(
        uint256 _hatId,
        uint32 _level
    ) public pure returns (uint256 admin) {
        uint256 mask = type(uint256).max <<
            (LOWER_LEVEL_ADDRESS_SPACE * (MAX_LEVELS - _level));

        admin = _hatId & mask;
    }

    /// @notice Gets the tophat domain of a given hat
    /// @dev A domain is the identifier for a given hat tree, stored in the first 4 bytes of a hat's id
    /// @param _hatId the id of the hat in question
    /// @return domain The domain of the hat's tophat
    function getTopHatDomain(
        uint256 _hatId
    ) public pure returns (uint32 domain) {
        domain = uint32(_hatId >> (LOWER_LEVEL_ADDRESS_SPACE * MAX_LEVELS));
    }

    /// @notice Gets the domain of the highest parent tophat — the "tippy tophat"
    /// @param _topHatDomain the 32 bit domain of a (likely linked) tophat
    /// @return domain The tippy tophat domain
    function getTippyTopHatDomain(
        uint32 _topHatDomain
    ) public view returns (uint32 domain) {
        uint256 linkedAdmin = linkedTreeAdmins[_topHatDomain];
        if (linkedAdmin == 0) return domain = _topHatDomain;
        return domain = getTippyTopHatDomain(getTopHatDomain(linkedAdmin));
    }

    /// @notice Checks For any circular linkage of trees
    /// @param _topHatDomain the 32 bit domain of the tree to be linked
    /// @param _linkedAdmin the hatId of the potential tree admin
    /// @return notCircular circular link has not been found
    function noCircularLinkage(
        uint32 _topHatDomain,
        uint256 _linkedAdmin
    ) public view returns (bool notCircular) {
        if (_linkedAdmin == 0) return true;
        uint32 adminDomain = getTopHatDomain(_linkedAdmin);
        if (_topHatDomain == adminDomain) return false;
        uint256 parentAdmin = linkedTreeAdmins[adminDomain];
        return noCircularLinkage(_topHatDomain, parentAdmin);
    }

    /// @notice Checks that a tophat domain and its potential linked admin are from the same tree, ie have the same tippy tophat domain
    /// @param _topHatDomain The 32 bit domain of the tophat to be linked
    /// @param _newAdminHat The new admin for the linked tree
    /// @return sameDomain Whether the _topHatDomain and the domain of its potential linked _newAdminHat domains are the same
    function sameTippyTopHatDomain(
        uint32 _topHatDomain,
        uint256 _newAdminHat
    ) public view returns (bool sameDomain) {
        // get highest parent domains for current and new tree root admins
        uint32 currentTippyTophatDomain = getTippyTopHatDomain(_topHatDomain);
        uint32 newAdminDomain = getTopHatDomain(_newAdminHat);
        uint32 newHTippyTophatDomain = getTippyTopHatDomain(newAdminDomain);

        // check that both domains are equal
        sameDomain = (currentTippyTophatDomain == newHTippyTophatDomain);
    }
}

contract MockHats is IHats, ERC1155, MockHatsIdUtilities {
    struct Hat {
        // 1st storage slot
        address eligibility; // ─┐ 20
        uint32 maxSupply; //     │ 4
        uint32 supply; //        │ 4
        uint16 lastHatId; //    ─┘ 2
        // 2nd slot
        address toggle; //      ─┐ 20
        uint96 config; //       ─┘ 12
        // 3rd+ slot (optional)
        string details;
        string imageURI;
    }

    mapping(uint256 => Hat) internal _hats;
    mapping(uint256 => mapping(address => bool)) public badStandings;

    uint32 public lastTopHatId;

    event HatCreated(uint256 hatId);

    function mintTopHat(
        address _target,
        string calldata _details,
        string calldata _imageURI
    ) external returns (uint256 topHatId) {
        topHatId = uint256(++lastTopHatId) << 224;

        _createHat(
            topHatId,
            _details, // details
            1, // maxSupply = 1
            address(0), // there is no eligibility
            address(0), // it has no toggle
            false, // its immutable
            _imageURI
        );

        _mintHat(_target, topHatId);
    }

    function _mintHat(address _wearer, uint256 _hatId) internal {
        unchecked {
            // should not overflow since `mintHat` enforces max balance of 1
            _balanceOf[_wearer][_hatId] = 1;

            // increment Hat supply counter
            // should not overflow given AllHatsWorn check in `mintHat`
            ++_hats[_hatId].supply;
        }

        emit TransferSingle(msg.sender, address(0), _wearer, _hatId, 1);
    }

    function createHat(
        uint256 _admin,
        string calldata _details,
        uint32 _maxSupply,
        address _eligibility,
        address _toggle,
        bool _mutable,
        string calldata _imageURI
    ) public returns (uint256 newHatId) {
        if (uint16(_admin) > 0) {
            revert MaxLevelsReached();
        }

        if (_eligibility == address(0)) revert ZeroAddress();
        if (_toggle == address(0)) revert ZeroAddress();
        // check that the admin id is valid, ie does not contain empty levels between filled levels
        if (!isValidHatId(_admin)) revert InvalidHatId();
        // construct the next hat id
        newHatId = getNextId(_admin);
        // to create a hat, you must be wearing one of its admin hats
        _checkAdmin(newHatId);
        // create the new hat
        _createHat(
            newHatId,
            _details,
            _maxSupply,
            _eligibility,
            _toggle,
            _mutable,
            _imageURI
        );
        // increment _admin.lastHatId
        // use the overflow check to constrain to correct number of hats per level
        ++_hats[_admin].lastHatId;
    }

    function getNextId(uint256 _admin) public view returns (uint256 nextId) {
        uint16 nextHatId = _hats[_admin].lastHatId + 1;
        nextId = buildHatId(_admin, nextHatId);
    }

    function getNextIdOffset(
        uint256 _admin,
        uint8 _offset
    ) public view returns (uint256 nextId) {
        uint16 nextHatId = _hats[_admin].lastHatId + 1 + _offset;
        nextId = buildHatId(_admin, nextHatId);
    }

    function _createHat(
        uint256 _id,
        string calldata _details,
        uint32 _maxSupply,
        address _eligibility,
        address _toggle,
        bool _mutable,
        string calldata _imageURI
    ) internal {
        /* 
          We write directly to storage instead of first building the Hat struct in memory.
          This allows us to cheaply use the existing lastHatId value in case it was incremented by creating a hat while skipping admin levels.
          (Resetting it to 0 would be bad since this hat's child hat(s) would overwrite the previously created hat(s) at that level.)
        */
        Hat storage hat = _hats[_id];
        hat.details = _details;
        hat.maxSupply = _maxSupply;
        hat.eligibility = _eligibility;
        hat.toggle = _toggle;
        hat.imageURI = _imageURI;
        // config is a concatenation of the status and mutability properties
        hat.config = _mutable ? uint96(3 << 94) : uint96(1 << 95);

        emit HatCreated(
            _id,
            _details,
            _maxSupply,
            _eligibility,
            _toggle,
            _mutable,
            _imageURI
        );
    }

    function mintHat(
        uint256 _hatId,
        address _wearer
    ) public returns (bool success) {
        Hat storage hat = _hats[_hatId];
        if (hat.maxSupply == 0) revert HatDoesNotExist(_hatId);
        // only eligible wearers can receive minted hats
        if (!isEligible(_wearer, _hatId)) revert NotEligible();
        // only active hats can be minted
        if (!_isActive(hat, _hatId)) revert HatNotActive();
        // only the wearer of one of a hat's admins can mint it
        _checkAdmin(_hatId);
        // hat supply cannot exceed maxSupply
        if (hat.supply >= hat.maxSupply) revert AllHatsWorn(_hatId);
        // wearers cannot wear the same hat more than once
        if (_staticBalanceOf(_wearer, _hatId) > 0)
            revert AlreadyWearingHat(_wearer, _hatId);
        // if we've made it through all the checks, mint the hat
        _mintHat(_wearer, _hatId);

        success = true;
    }

    function transferHat(uint256 _hatId, address _from, address _to) public {
        _checkAdmin(_hatId);
        // cannot transfer immutable hats, except for tophats, which can always transfer themselves
        if (!isTopHat(_hatId)) {
            if (!_isMutable(_hats[_hatId])) revert Immutable();
        }
        // Checks storage instead of `isWearerOfHat` since admins may want to transfer revoked Hats to new wearers
        if (_staticBalanceOf(_from, _hatId) < 1) revert NotHatWearer();
        // Check if recipient is already wearing hat; also checks storage to maintain balance == 1 invariant
        if (_staticBalanceOf(_to, _hatId) > 0)
            revert AlreadyWearingHat(_to, _hatId);
        // only eligible wearers can receive transferred hats
        if (!isEligible(_to, _hatId)) revert NotEligible();
        // only active hats can be transferred
        if (!_isActive(_hats[_hatId], _hatId)) revert HatNotActive();
        // we've made it passed all the checks, so adjust balances to execute the transfer
        _balanceOf[_from][_hatId] = 0;
        _balanceOf[_to][_hatId] = 1;
        // emit the ERC1155 standard transfer event
        emit TransferSingle(msg.sender, _from, _to, _hatId, 1);
    }

    function _staticBalanceOf(
        address _account,
        uint256 _hatId
    ) internal view returns (uint256 staticBalance) {
        staticBalance = _balanceOf[_account][_hatId];
    }

    function _isMutable(
        Hat storage _hat
    ) internal view returns (bool _mutable) {
        _mutable = (_hat.config & uint96(1 << 94) != 0);
    }

    function getHatEligibilityModule(
        uint256 _hatId
    ) external view returns (address eligibility) {
        eligibility = _hats[_hatId].eligibility;
    }

    function changeHatEligibility(
        uint256 _hatId,
        address _newEligibility
    ) external {
        if (_newEligibility == address(0)) revert ZeroAddress();

        _checkAdmin(_hatId);
        Hat storage hat = _hats[_hatId];

        if (!_isMutable(hat)) {
            revert Immutable();
        }

        hat.eligibility = _newEligibility;

        emit HatEligibilityChanged(_hatId, _newEligibility);
    }

    function batchCreateHats(
        uint256[] calldata _admins,
        string[] calldata _details,
        uint32[] calldata _maxSupplies,
        address[] memory _eligibilityModules,
        address[] memory _toggleModules,
        bool[] calldata _mutables,
        string[] calldata _imageURIs
    ) external override returns (bool success) {}

    function batchMintHats(
        uint256[] calldata _hatIds,
        address[] calldata _wearers
    ) external override returns (bool success) {}

    function setHatStatus(
        uint256 _hatId,
        bool _newStatus
    ) external override returns (bool toggled) {}

    function checkHatStatus(
        uint256 _hatId
    ) external override returns (bool toggled) {}

    function setHatWearerStatus(
        uint256 _hatId,
        address _wearer,
        bool _eligible,
        bool _standing
    ) external override returns (bool updated) {}

    function checkHatWearerStatus(
        uint256 _hatId,
        address _wearer
    ) public returns (bool updated) {
        bool eligible;
        bool standing;

        (bool success, bytes memory returndata) = _hats[_hatId]
            .eligibility
            .staticcall(
                abi.encodeWithSignature(
                    "getWearerStatus(address,uint256)",
                    _wearer,
                    _hatId
                )
            );

        /*
         * if function call succeeds with data of length == 64, then we know the contract exists
         * and has the getWearerStatus function (which returns two words).
         * But — since function selectors don't include return types — we still can't assume that the return data is two booleans,
         * so we treat it as a uint so it will always safely decode without throwing.
         */
        if (success && returndata.length == 64) {
            // check the returndata manually
            (uint256 firstWord, uint256 secondWord) = abi.decode(
                returndata,
                (uint256, uint256)
            );
            // returndata is valid
            if (firstWord < 2 && secondWord < 2) {
                standing = (secondWord == 1) ? true : false;
                // never eligible if in bad standing
                eligible = (standing && firstWord == 1) ? true : false;
            }
            // returndata is invalid
            else {
                revert NotHatsEligibility();
            }
        } else {
            revert NotHatsEligibility();
        }

        updated = _processHatWearerStatus(_hatId, _wearer, eligible, standing);
    }

    function _processHatWearerStatus(
        uint256 _hatId,
        address _wearer,
        bool _eligible,
        bool _standing
    ) internal returns (bool updated) {
        // revoke/burn the hat if _wearer has a positive balance
        if (_staticBalanceOf(_wearer, _hatId) > 0) {
            // always ineligible if in bad standing
            if (!_eligible || !_standing) {
                _burnHat(_wearer, _hatId);
            }
        }

        // record standing for use by other contracts
        // note: here, standing and badStandings are opposite
        // i.e. if standing (true = good standing)
        // then badStandings[_hatId][wearer] will be false
        // if they are different, then something has changed, and we need to update
        // badStandings marker
        if (_standing == badStandings[_hatId][_wearer]) {
            badStandings[_hatId][_wearer] = !_standing;
            updated = true;

            emit WearerStandingChanged(_hatId, _wearer, _standing);
        }
    }

    function _burnHat(address _wearer, uint256 _hatId) internal {
        // neither should underflow since `_burnHat` is never called on non-positive balance
        unchecked {
            _balanceOf[_wearer][_hatId] = 0;

            // decrement Hat supply counter
            --_hats[_hatId].supply;
        }

        emit TransferSingle(msg.sender, _wearer, address(0), _hatId, 1);
    }

    function renounceHat(uint256 _hatId) external override {}

    function makeHatImmutable(uint256 _hatId) external override {}

    function changeHatDetails(
        uint256 _hatId,
        string memory _newDetails
    ) external override {}

    function changeHatToggle(
        uint256 _hatId,
        address _newToggle
    ) external override {}

    function changeHatImageURI(
        uint256 _hatId,
        string memory _newImageURI
    ) external override {}

    function changeHatMaxSupply(
        uint256 _hatId,
        uint32 _newMaxSupply
    ) external override {}

    function requestLinkTopHatToTree(
        uint32 _topHatId,
        uint256 _newAdminHat
    ) external override {}

    function approveLinkTopHatToTree(
        uint32 _topHatId,
        uint256 _newAdminHat,
        address _eligibility,
        address _toggle,
        string calldata _details,
        string calldata _imageURI
    ) external override {}

    function unlinkTopHatFromTree(
        uint32 _topHatId,
        address _wearer
    ) external override {}

    function relinkTopHatWithinTree(
        uint32 _topHatDomain,
        uint256 _newAdminHat,
        address _eligibility,
        address _toggle,
        string calldata _details,
        string calldata _imageURI
    ) external override {}

    function viewHat(
        uint256 _hatId
    )
        external
        view
        override
        returns (
            string memory _details,
            uint32 _maxSupply,
            uint32 _supply,
            address _eligibility,
            address _toggle,
            string memory _imageURI,
            uint16 _lastHatId,
            bool _mutable,
            bool _active
        )
    {}

    function isInGoodStanding(
        address _wearer,
        uint256 _hatId
    ) external view override returns (bool standing) {}

    function isEligible(
        address _wearer,
        uint256 _hatId
    ) public view returns (bool eligible) {
        eligible = _isEligible(_wearer, _hats[_hatId], _hatId);
    }

    function getHatToggleModule(
        uint256 _hatId
    ) external view override returns (address toggle) {}

    function getHatMaxSupply(
        uint256 _hatId
    ) external view override returns (uint32 maxSupply) {}

    function hatSupply(
        uint256 _hatId
    ) external view override returns (uint32 supply) {}

    function getImageURIForHat(
        uint256 _hatId
    ) external view override returns (string memory _uri) {}

    function balanceOf(
        address _wearer,
        uint256 _hatId
    ) public view override(ERC1155, IHats) returns (uint256 balance) {
        Hat storage hat = _hats[_hatId];

        balance = 0;

        if (_isActive(hat, _hatId) && _isEligible(_wearer, hat, _hatId)) {
            balance = super.balanceOf(_wearer, _hatId);
        }
    }

    function balanceOfBatch(
        address[] calldata _wearers,
        uint256[] calldata _hatIds
    ) public view override(ERC1155, IHats) returns (uint256[] memory balances) {
        if (_wearers.length != _hatIds.length)
            revert BatchArrayLengthMismatch();

        balances = new uint256[](_wearers.length);

        // Unchecked because the only math done is incrementing
        // the array index counter which cannot possibly overflow.
        unchecked {
            for (uint256 i; i < _wearers.length; ++i) {
                balances[i] = balanceOf(_wearers[i], _hatIds[i]);
            }
        }
    }

    function uri(
        uint256
    ) public pure override(ERC1155, IHats) returns (string memory _uri) {
        _uri = "";
    }

    /// @notice Checks whether msg.sender is an admin of a hat, and reverts if not
    function _checkAdmin(uint256 _hatId) internal view {
        if (!isAdminOfHat(msg.sender, _hatId)) {
            revert NotAdmin(msg.sender, _hatId);
        }
    }

    /// @notice Checks whether a given address serves as the admin of a given Hat
    /// @dev Recursively checks if `_user` wears the admin Hat of the Hat in question. This is recursive since there may be a string of Hats as admins of Hats.
    /// @param _user The address in question
    /// @param _hatId The id of the Hat for which the `_user` might be the admin
    /// @return isAdmin Whether the `_user` has admin rights for the Hat
    function isAdminOfHat(
        address _user,
        uint256 _hatId
    ) public view returns (bool isAdmin) {
        uint256 linkedTreeAdmin;
        uint32 adminLocalHatLevel;
        if (isLocalTopHat(_hatId)) {
            linkedTreeAdmin = linkedTreeAdmins[getTopHatDomain(_hatId)];
            if (linkedTreeAdmin == 0) {
                // tree is not linked
                return isAdmin = isWearerOfHat(_user, _hatId);
            } else {
                // tree is linked
                if (isWearerOfHat(_user, linkedTreeAdmin)) {
                    return isAdmin = true;
                }
                // user wears the treeAdmin
                else {
                    adminLocalHatLevel = getLocalHatLevel(linkedTreeAdmin);
                    _hatId = linkedTreeAdmin;
                }
            }
        } else {
            // if we get here, _hatId is not a tophat of any kind
            // get the local tree level of _hatId's admin
            adminLocalHatLevel = getLocalHatLevel(_hatId) - 1;
        }

        // search up _hatId's local address space for an admin hat that the _user wears
        while (adminLocalHatLevel > 0) {
            if (
                isWearerOfHat(
                    _user,
                    getAdminAtLocalLevel(_hatId, adminLocalHatLevel)
                )
            ) {
                return isAdmin = true;
            }
            // should not underflow given stopping condition > 0
            unchecked {
                --adminLocalHatLevel;
            }
        }

        // if we get here, we've reached the top of _hatId's local tree, ie the local tophat
        // check if the user wears the local tophat
        if (isWearerOfHat(_user, getAdminAtLocalLevel(_hatId, 0)))
            return isAdmin = true;

        // if not, we check if it's linked to another tree
        linkedTreeAdmin = linkedTreeAdmins[getTopHatDomain(_hatId)];
        if (linkedTreeAdmin == 0) {
            // tree is not linked
            // we've already learned that user doesn't wear the local tophat, so there's nothing else to check; we return false
            return isAdmin = false;
        } else {
            // tree is linked
            // check if user is wearer of linkedTreeAdmin
            if (isWearerOfHat(_user, linkedTreeAdmin)) return true;
            // if not, recurse to traverse the parent tree for a hat that the user wears
            isAdmin = isAdminOfHat(_user, linkedTreeAdmin);
        }
    }

    function isWearerOfHat(
        address _user,
        uint256 _hatId
    ) public view returns (bool isWearer) {
        isWearer = (balanceOf(_user, _hatId) > 0);
    }

    function _isActive(
        Hat storage _hat,
        uint256 _hatId
    ) internal view returns (bool active) {
        (bool success, bytes memory returndata) = _hat.toggle.staticcall(
            abi.encodeWithSignature("getHatStatus(uint256)", _hatId)
        );

        /*
         * if function call succeeds with data of length == 32, then we know the contract exists
         * and has the getHatStatus function.
         * But — since function selectors don't include return types — we still can't assume that the return data is a boolean,
         * so we treat it as a uint so it will always safely decode without throwing.
         */
        if (success && returndata.length == 32) {
            // check the returndata manually
            uint256 uintReturndata = uint256(bytes32(returndata));
            // false condition
            if (uintReturndata == 0) {
                active = false;
                // true condition
            } else if (uintReturndata == 1) {
                active = true;
            }
            // invalid condition
            else {
                active = _getHatStatus(_hat);
            }
        } else {
            active = _getHatStatus(_hat);
        }
    }

    function _isEligible(
        address _wearer,
        Hat storage _hat,
        uint256 _hatId
    ) internal view returns (bool eligible) {
        (bool success, bytes memory returndata) = _hat.eligibility.staticcall(
            abi.encodeWithSignature(
                "getWearerStatus(address,uint256)",
                _wearer,
                _hatId
            )
        );

        /*
         * if function call succeeds with data of length == 64, then we know the contract exists
         * and has the getWearerStatus function (which returns two words).
         * But — since function selectors don't include return types — we still can't assume that the return data is two booleans,
         * so we treat it as a uint so it will always safely decode without throwing.
         */
        if (success && returndata.length == 64) {
            bool standing;
            // check the returndata manually
            (uint256 firstWord, uint256 secondWord) = abi.decode(
                returndata,
                (uint256, uint256)
            );
            // returndata is valid
            if (firstWord < 2 && secondWord < 2) {
                standing = (secondWord == 1) ? true : false;
                // never eligible if in bad standing
                eligible = (standing && firstWord == 1) ? true : false;
            }
            // returndata is invalid
            else {
                eligible = !badStandings[_hatId][_wearer];
            }
        } else {
            eligible = !badStandings[_hatId][_wearer];
        }
    }

    function _getHatStatus(
        Hat storage _hat
    ) internal view returns (bool status) {
        status = (_hat.config >> 95 != 0);
    }
}
