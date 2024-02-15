// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {GAME_NFT_CONTRACT_ROLE, GAME_ITEMS_CONTRACT_ROLE, GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {IGameItems} from "../tokens/gameitems/IGameItems.sol";
import {ILockingSystem, ID} from "./ILockingSystem.sol";

import "../GameRegistryConsumerUpgradeable.sol";

/**
 * @title LockingSystem
 *
 * Contract that allows the locking and unlocking of various token types within the game ecosystem
 * Locking ensures that the tokens cannot be transferred while they are being used in-game
 * This allows the tokens to remain in the user's wallet but still gives the game predictability that the assets won't disappear mid-game action
 */
contract LockingSystem is ILockingSystem, GameRegistryConsumerUpgradeable {
    using Counters for Counters.Counter;

    // Struct to track a reservation made by the game for an NFT
    struct NFTReservation {
        // Whether or not this reservation is exclusive and prevents tokens from being used by other reservations
        bool exclusive;
        // When the reservation was made
        uint32 timestamp;
        // Data determined by the reserver, can be used to identify the reservation source
        uint32 data;
    }

    // Struct to track a reservation made by the game for an item
    struct ItemReservation {
        // Number of tokens reserved
        uint256 amount;
        // Whether or not this reservation is exclusive and prevents tokens from being used by other reservations
        bool exclusive;
        // When the reservation was made
        uint32 timestamp;
        // Data determined by the reserver, can be used to identify the reservation source
        uint32 data;
    }

    // Track a ERC721 NFT lock
    struct NFTLockStatus {
        // Whether or not NFT is locked
        bool locked;
        // Whether or not the NFT has an exclusive reservation
        bool hasExclusiveReservation;
        // All of the reservations made by the game
        uint32[] reservationIds;
        // Reservation id to reservation
        mapping(uint32 => NFTReservation) reservations;
        // Reservation id to index
        mapping(uint32 => uint32) reservationIndexes;
    }

    // Track a ERC1155 item lock
    struct ItemLockStatus {
        // Amount locked
        uint256 amountLocked;
        // Total number of tokens exclusively reserved, 0 or 1 for NFTs, any number for GameItems
        uint256 amountExclusivelyReserved;
        // Largest soft reservation size
        uint256 maxNonExclusiveReserved;
        // Timestamp the lock was last updated
        uint32 timestamp;
        // All of the reservations made by the game
        uint32[] reservationIds;
        // Reservation id to reservation
        mapping(uint32 => ItemReservation) reservations;
        // Reservation id to index
        mapping(uint32 => uint32) reservationIndexes;
    }

    // Mapping from account -> tokenContract -> tokenId -> ItemLockStatus
    mapping(address => mapping(address => mapping(uint256 => ItemLockStatus)))
        private _lockedItems;

    // Mapping from tokenContract -> tokenId -> NFTLockStatus
    mapping(address => mapping(uint256 => NFTLockStatus)) private _lockedNFTs;

    // Failsafe to allow the user to unlock regardless of game-state
    bool public rescueUnlockEnabled;

    // Counter to track reservation id
    Counters.Counter private _currentReservationId;

    /** ERRORS **/

    /// @notice Account is not the owner of the given NFT
    error NotOwner();

    /// @notice Contract not allowlisted for locking
    error ContractNotAllowlisted(address tokenContract);

    /// @notice Reservation id was invalid
    error ReservationNotFound();

    /// @notice Not enough locked tokens available to reserve
    error NotEnoughUnlockedTokens(uint256 expected, uint256 available);

    /// @notice Invalid amount specified
    error InvalidAmount();

    /// @notice Rescue mode is not enabled
    error RescueNotEnabled();

    /// @notice NFT is already exclusively locked
    error NFTAlreadyExclusivelyReserved();

    /** EVENTS */

    /// @notice When an NFT is locked
    event NFTLocked(address indexed tokenContract, uint256 indexed tokenId);

    /// @notice When an NFT is unlocked
    event NFTUnlocked(address indexed tokenContract, uint256 indexed tokenId);

    /// @notice When an item is locked
    event ItemLocked(
        address indexed account,
        address indexed tokenContract,
        uint256 indexed tokenId,
        uint256 amount
    );

    /// @notice When an item is unlocked
    event ItemUnlocked(
        address indexed account,
        address indexed tokenContract,
        uint256 indexed tokenId,
        uint256 amount
    );

    /** SETUP **/

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
        rescueUnlockEnabled = false;
    }

    /**
     * Lets the game add a reservation to a given NFT, this prevents the NFT from being unlocked
     *
     * @param tokenContract   Token contract address
     * @param tokenId         Token id to reserve
     * @param exclusive       Whether or not the reservation is exclusive. Exclusive reservations prevent other reservations from using the tokens by removing them from the pool.
     * @param data            Data determined by the reserver, can be used to identify the source of the reservation for display in UI
     */
    function addNFTReservation(
        address tokenContract,
        uint256 tokenId,
        bool exclusive,
        uint32 data
    )
        external
        override
        nonReentrant
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (uint32)
    {
        NFTLockStatus storage lockStatus = _lockedNFTs[tokenContract][tokenId];

        // Make sure NFT is valid
        if (_hasAccessRole(GAME_NFT_CONTRACT_ROLE, tokenContract) != true) {
            revert ContractNotAllowlisted(tokenContract);
        }

        // Cannot have more than one exclusive reservation on an NFT
        if (exclusive == true && lockStatus.hasExclusiveReservation == true) {
            revert NFTAlreadyExclusivelyReserved();
        }

        // Get reservation id
        uint32 reservationId = _nextReservationId();

        // Whether or not the NFT should be held exclusively
        if (exclusive) {
            lockStatus.hasExclusiveReservation = true;
        }

        // Store reservation
        lockStatus.reservations[reservationId] = NFTReservation({
            exclusive: exclusive,
            timestamp: uint32(block.timestamp),
            data: data
        });

        // Add to reservationId array
        lockStatus.reservationIds.push(reservationId);

        // Add to index mapping
        lockStatus.reservationIndexes[reservationId] = uint32(
            lockStatus.reservationIds.length - 1
        );

        // Set locked flag
        if (lockStatus.locked == false) {
            lockStatus.locked = true;

            // Emit event
            emit NFTLocked(tokenContract, tokenId);
        }

        // Return reservationId so the calling contract can remove the reservation later
        return reservationId;
    }

    /**
     * Lets the game remove a reservation from a given token
     *
     * @param tokenContract Token contract
     * @param tokenId       Id of the token
     * @param reservationId Id of the reservation to remove
     */
    function removeNFTReservation(
        address tokenContract,
        uint256 tokenId,
        uint32 reservationId
    ) external override nonReentrant onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        NFTLockStatus storage lockStatus = _lockedNFTs[tokenContract][tokenId];
        NFTReservation storage reservation = lockStatus.reservations[
            reservationId
        ];

        // Make sure reservation exists
        if (reservation.timestamp == 0) {
            revert ReservationNotFound();
        }

        // Remove from Ids array
        uint32 index = lockStatus.reservationIndexes[reservationId];
        if (index != lockStatus.reservationIds.length - 1) {
            uint32 lastId = lockStatus.reservationIds[
                lockStatus.reservationIds.length - 1
            ];
            lockStatus.reservationIds[index] = lastId;
            lockStatus.reservationIndexes[lastId] = index;
        }

        // Remove from all array
        lockStatus.reservationIds.pop();

        // Update the reserved amount if it was an exclusive reservation
        if (reservation.exclusive) {
            lockStatus.hasExclusiveReservation = false;
        }

        // Delete the reservation mapping
        delete lockStatus.reservations[reservationId];

        // Delete index mapping
        delete lockStatus.reservationIndexes[reservationId];

        // Unset flag if we have no reservations left
        if (
            lockStatus.reservationIds.length == 0 && lockStatus.locked == true
        ) {
            lockStatus.locked = false;

            // Emit event
            emit NFTUnlocked(tokenContract, tokenId);
        }
    }

    /**
     * Lets the game add a reservation to a given token, this prevents the token from being unlocked
     *
     * @param account  			  Account to reserve tokens for
     * @param tokenContract   Token contract address
     * @param tokenId  				Token id to reserve
     * @param amount 					Number of tokens to reserve (1 for NFTs, >=1 for ERC1155)
     * @param exclusive				Whether or not the reservation is exclusive. Exclusive reservations prevent other reservations from using the tokens by removing them from the pool.
     * @param data            Data determined by the reserver, can be used to identify the source of the reservation for display in UI
     */
    function addItemReservation(
        address account,
        address tokenContract,
        uint256 tokenId,
        uint256 amount,
        bool exclusive,
        uint32 data
    )
        external
        override
        nonReentrant
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (uint32)
    {
        ItemLockStatus storage lockStatus = _lockedItems[account][
            tokenContract
        ][tokenId];

        if (amount == 0) {
            revert InvalidAmount();
        }

        if (_hasAccessRole(GAME_ITEMS_CONTRACT_ROLE, tokenContract) == false) {
            revert ContractNotAllowlisted(tokenContract);
        }

        uint256 balance = IGameItems(tokenContract).balanceOf(account, tokenId);
        uint256 availableForLocking = exclusive == false
            ? balance - lockStatus.amountExclusivelyReserved
            : _itemAmountUnlocked(balance, lockStatus);

        if (amount > availableForLocking) {
            revert NotEnoughUnlockedTokens(amount, availableForLocking);
        }

        // Get reservation id
        uint32 reservationId = _nextReservationId();

        if (exclusive) {
            lockStatus.amountExclusivelyReserved += amount;
        } else {
            if (amount > lockStatus.maxNonExclusiveReserved) {
                lockStatus.maxNonExclusiveReserved = amount;
            }
        }

        lockStatus.reservations[reservationId] = ItemReservation({
            exclusive: exclusive,
            timestamp: uint32(block.timestamp),
            amount: amount,
            data: data
        });

        // Add to reservationId array
        lockStatus.reservationIds.push(reservationId);

        // Add to index mapping
        lockStatus.reservationIndexes[reservationId] = uint32(
            lockStatus.reservationIds.length - 1
        );

        // Update lock status
        uint256 oldLockedAmount = lockStatus.amountLocked;
        lockStatus.amountLocked =
            lockStatus.amountExclusivelyReserved +
            lockStatus.maxNonExclusiveReserved;

        // Emit delta when locking more items
        if (lockStatus.amountLocked > oldLockedAmount) {
            emit ItemLocked(
                account,
                tokenContract,
                tokenId,
                lockStatus.amountLocked - oldLockedAmount
            );
        }

        // Return reservationId so the calling contract can remove the reservation later
        return reservationId;
    }

    /**
     * Lets the game remove a reservation from a given token
     *
     * @param account   			Owner to remove reservation from
     * @param tokenContract	Token contract
     * @param tokenId  			Id of the token
     * @param reservationId Id of the reservation to remove
     */
    function removeItemReservation(
        address account,
        address tokenContract,
        uint256 tokenId,
        uint32 reservationId
    ) external override nonReentrant onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        ItemLockStatus storage lockStatus = _lockedItems[account][
            tokenContract
        ][tokenId];
        ItemReservation storage reservation = lockStatus.reservations[
            reservationId
        ];

        // Make sure reservation exists
        if (reservation.timestamp == 0) {
            revert ReservationNotFound();
        }

        // Remove from Ids array
        uint32 index = lockStatus.reservationIndexes[reservationId];
        if (index != lockStatus.reservationIds.length - 1) {
            uint32 lastId = lockStatus.reservationIds[
                lockStatus.reservationIds.length - 1
            ];
            lockStatus.reservationIds[index] = lastId;
            lockStatus.reservationIndexes[lastId] = index;
        }

        // Remove from all array
        lockStatus.reservationIds.pop();

        // Update the reserved amount if it was an exclusive reservation
        if (reservation.exclusive) {
            lockStatus.amountExclusivelyReserved -= reservation.amount;
        } else {
            // Calculate number of items needed for non-exclusive reservation
            uint256 max = 0;
            for (uint256 idx; idx < lockStatus.reservationIds.length; ++idx) {
                ItemReservation storage otherReservation = lockStatus
                    .reservations[lockStatus.reservationIds[idx]];
                if (
                    otherReservation.exclusive == false &&
                    otherReservation.amount > max
                ) {
                    max = otherReservation.amount;
                }
            }

            lockStatus.maxNonExclusiveReserved = max;
        }

        // Delete the reservation mapping
        delete lockStatus.reservations[reservationId];

        // Delete index mapping
        delete lockStatus.reservationIndexes[reservationId];

        // Update lock status
        uint256 oldLockedAmount = lockStatus.amountLocked;
        lockStatus.amountLocked =
            lockStatus.amountExclusivelyReserved +
            lockStatus.maxNonExclusiveReserved;

        // Emit delta when locking more items
        if (lockStatus.amountLocked < oldLockedAmount) {
            emit ItemUnlocked(
                account,
                tokenContract,
                tokenId,
                oldLockedAmount - lockStatus.amountLocked
            );
        }
    }

    /**
     * Whether or not the given items can be transferred
     *
     * @param account   	    Token owner
     * @param tokenContract	    Token contract address
     * @param ids               Ids of the tokens
     * @param amounts           Amounts of the tokens
     *
     * @return Whether or not the given items can be transferred
     */
    function canTransferItems(
        address account,
        address tokenContract,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external view returns (bool) {
        for (uint8 idx; idx < ids.length; ++idx) {
            uint256 id = ids[idx];
            uint256 amount = amounts[idx];
            ItemLockStatus storage lockStatus = _lockedItems[account][
                tokenContract
            ][id];

            uint256 available = IGameItems(tokenContract).balanceOf(
                account,
                id
            ) - lockStatus.amountLocked;
            if (available < amount) {
                return false;
            }
        }

        return true;
    }

    /**
     * Set/unset emergency unstake mode
     *
     * @param _enabled Whether or not to enable the mode
     */
    function setRescueUnlockEnabled(bool _enabled) external onlyOwner {
        rescueUnlockEnabled = _enabled;
    }

    /** @return Whether or not rescue unlock mode is enabled */
    function getRescueUnlockEnabled() external view returns (bool) {
        return rescueUnlockEnabled;
    }

    /**
     * @notice Bypasses all reservations and lets the user forcibly unlock their NFT
     *
     * @param tokenContract  Token Contract to unlock
     * @param tokenId        Token Id to unlock
     */
    function rescueUnlockNFT(address tokenContract, uint256 tokenId)
        external
        nonReentrant
    {
        if (rescueUnlockEnabled != true) {
            revert RescueNotEnabled();
        }

        if (IERC721(tokenContract).ownerOf(tokenId) != _msgSender()) {
            revert NotOwner();
        }

        // Remove lock
        if (_lockedNFTs[tokenContract][tokenId].locked == true) {
            _lockedNFTs[tokenContract][tokenId].locked = false;
            emit NFTUnlocked(tokenContract, tokenId);
        }

        delete _lockedNFTs[tokenContract][tokenId];
    }

    /**
     * @notice Bypasses all reservations and lets the user forcibly unlock their items.
     *
     * @param account        Account to unlock items for
     * @param tokenContract  Token Contract to unlock
     * @param tokenId        Token Id to unlock
     */
    function rescueUnlockItems(
        address account,
        address tokenContract,
        uint256 tokenId
    ) external nonReentrant {
        if (rescueUnlockEnabled != true) {
            revert RescueNotEnabled();
        }

        if (account != _msgSender()) {
            revert NotOwner();
        }

        ItemLockStatus storage lockStatus = _lockedItems[account][
            tokenContract
        ][tokenId];

        // Unlock token, if locked
        uint256 amountLocked = lockStatus.amountLocked;
        if (amountLocked > 0) {
            lockStatus.amountLocked = 0;

            // Emit event
            emit ItemUnlocked(account, tokenContract, tokenId, amountLocked);
        }

        // Delete any lock data
        delete _lockedItems[account][tokenContract][tokenId];
    }

    /** @return All the reservations for a NFT */
    function getNFTReservationIds(address tokenContract, uint256 tokenId)
        external
        view
        returns (uint32[] memory)
    {
        NFTLockStatus storage lockStatus = _lockedNFTs[tokenContract][tokenId];

        return lockStatus.reservationIds;
    }

    /** @return A given reservation for an NFT */
    function getNFTReservation(
        address tokenContract,
        uint256 tokenId,
        uint32 reservationId
    ) external view returns (NFTReservation memory) {
        NFTLockStatus storage lockStatus = _lockedNFTs[tokenContract][tokenId];

        // Make sure reservation exists
        NFTReservation memory reservation = lockStatus.reservations[
            reservationId
        ];
        // Make sure reservation exists
        if (reservation.timestamp == 0) {
            revert ReservationNotFound();
        }

        return reservation;
    }

    /** @return All the reservations for an item */
    function getItemReservationIds(
        address account,
        address tokenContract,
        uint256 tokenId
    ) external view returns (uint32[] memory) {
        ItemLockStatus storage lockStatus = _lockedItems[account][
            tokenContract
        ][tokenId];

        return lockStatus.reservationIds;
    }

    /** @return A given reservation for a locked item */
    function getItemReservation(
        address account,
        address tokenContract,
        uint256 tokenId,
        uint32 reservationId
    ) external view returns (ItemReservation memory) {
        ItemLockStatus storage lockStatus = _lockedItems[account][
            tokenContract
        ][tokenId];

        // Make sure reservation exists
        ItemReservation memory reservation = lockStatus.reservations[
            reservationId
        ];
        // Make sure reservation exists
        if (reservation.timestamp == 0) {
            revert ReservationNotFound();
        }

        return reservation;
    }

    /**
     * Whether or not an NFT is locked
     *
     * @param tokenContract Token contract address
     * @param tokenId       Id of the token
     */
    function isNFTLocked(address tokenContract, uint256 tokenId)
        external
        view
        override
        returns (bool)
    {
        NFTLockStatus storage lockStatus = _lockedNFTs[tokenContract][tokenId];

        return lockStatus.locked;
    }

    /**
     * Amount of token locked in the system by a given owner
     *
     * @param account   	  Token owner account
     * @param tokenContract	Token contract address
     * @param tokenId       Id of the token
     *
     * @return Number of tokens locked
     */
    function itemAmountLocked(
        address account,
        address tokenContract,
        uint256 tokenId
    ) external view override returns (uint256) {
        ItemLockStatus storage lockStatus = _lockedItems[account][
            tokenContract
        ][tokenId];
        return lockStatus.amountLocked;
    }

    /**
     * Amount of tokens available for unlock
     *
     * @param account         Token owner account
     * @param tokenContract Token contract address
     * @param tokenId       Id of the token
     *
     * @return Number of tokens locked
     */
    function itemAmountUnlocked(
        address account,
        address tokenContract,
        uint256 tokenId
    ) external view override returns (uint256) {
        ItemLockStatus storage lockStatus = _lockedItems[account][
            tokenContract
        ][tokenId];
        uint256 balance = IGameItems(tokenContract).balanceOf(account, tokenId);
        return _itemAmountUnlocked(balance, lockStatus);
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165)
        returns (bool)
    {
        return
            interfaceId == type(ILockingSystem).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    /*** INTERNAL ***/

    function _nextReservationId() internal returns (uint32) {
        _currentReservationId.increment();
        return SafeCast.toUint32(_currentReservationId.current());
    }

    /**
     * @param balance       Balance of the user
     * @param lockStatus    ItemLockStatus struct
     *
     * @return Number of tokens not locked
     */
    function _itemAmountUnlocked(
        uint256 balance,
        ItemLockStatus storage lockStatus
    ) internal view returns (uint256) {
        return
            balance -
            lockStatus.amountExclusivelyReserved -
            lockStatus.maxNonExclusiveReserved;
    }
}
