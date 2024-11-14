// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

import {ID as GAME_ITEMS_ID} from "../tokens/gameitems/IGameItems.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {Item, IEquippable} from "./IEquippable.sol";
import {ItemsEquippedComponent, ID as ITEMS_EQUIPPED_COMPONENT_ID} from "../generated/components/ItemsEquippedComponent.sol";
import {ItemSlotsPerLevelComponent, Layout as ItemSlotsPerLevelComponentLayout, ID as ITEM_SLOTS_PER_LEVEL_COMPONENT_ID} from "../generated/components/ItemSlotsPerLevelComponent.sol";
import {MixinComponent, ID as MIXIN_COMPONENT_ID} from "../generated/components/MixinComponent.sol";
import {CombatModifiersComponent, ID as COMBAT_MODIFIERS_COMPONENT_ID} from "../generated/components/CombatModifiersComponent.sol";
import {LevelComponent, ID as LEVEL_COMPONENT_ID} from "../generated/components/LevelComponent.sol";

import "../GameRegistryConsumerUpgradeable.sol";

/**
 * @title Equippable
 *
 * @dev implement this to add equipment loadout management to a contract
 * @dev requires role GAME_LOGIC_CONTRACT_ROLE and MINTER_ROLE
 */
abstract contract Equippable is GameRegistryConsumerUpgradeable, IEquippable {
    /** ERRORS **/

    /// @notice Invalid item cannot be equipped by parent
    error InvalidItem(uint256 itemEntity);

    /// @notice Item cannot be equipped to parent
    error ItemNonEquippableToParent(uint256 parentEntity, uint256 itemEntity);

    /// @notice Unauthorized item cannot be equipped by parent
    error UnauthorizedItem(address tokenContract, uint256 tokenId);

    /// @notice Invalid balance for item
    error InvalidBalance(uint256 tokenId);

    /// @notice Item cannot be equipped by invalid parent
    error InvalidParent();

    /// @notice Desired slot is invalid for item
    error InvalidSlot(uint256 slottedItemEntity, uint256 replaceItemEntity);

    /// @notice Desired slot index is invalid
    error InvalidSlotIndex(uint256 slotCount, uint256 indexUsed);

    /** EXTERNAL **/

    /**
     * @inheritdoc IEquippable
     */
    function getItems(
        uint256 parentEntity,
        uint256
    ) external view returns (uint256[] memory) {
        return _getItems(parentEntity);
    }

    /**
     * @inheritdoc IEquippable
     */
    function getSlotCount(
        uint256 parentEntity,
        uint256 slotType
    ) public view virtual returns (uint256);

    /**
     * @inheritdoc IEquippable
     */
    function removeItems(
        uint256 parentEntity,
        Item[] calldata items
    ) external whenNotPaused {
        address account = _getPlayerAccount(_msgSender());

        // Vaidate parentEntity belongs to caller
        if (!_isParentOwner(account, parentEntity)) {
            revert InvalidParent();
        }

        for (uint256 i = 0; i < items.length; ++i) {
            _removeItem(account, parentEntity, items[i]);
        }
    }

    /**
     * @inheritdoc IEquippable
     */
    function setItems(
        uint256 parentEntity,
        uint256[] calldata existingItems,
        Item[] calldata items
    ) external whenNotPaused {
        address account = _getPlayerAccount(_msgSender());

        // Vaidate parentEntity belongs to caller
        if (!_isParentOwner(account, parentEntity)) {
            revert InvalidParent();
        }

        for (uint256 i = 0; i < items.length; ++i) {
            _setItem(
                account,
                parentEntity,
                existingItems[items[i].slotIndex],
                items[i]
            );
        }
    }

    /** INTERNAL **/

    /**
     * @dev Returns the equipment loadout at a parent entity's slotType, or initializes a new one
     */
    function _getItems(
        uint256 parentEntity
    ) internal view returns (uint256[] memory) {
        uint256 mixinId = MixinComponent(
            _gameRegistry.getComponent(MIXIN_COMPONENT_ID)
        ).getValue(parentEntity)[0];
        uint256[] memory itemSlotsPerLevel = ItemSlotsPerLevelComponent(
            _gameRegistry.getComponent(ITEM_SLOTS_PER_LEVEL_COMPONENT_ID)
        ).getValue(mixinId);
        uint256 slotCount = itemSlotsPerLevel[
            LevelComponent(_gameRegistry.getComponent(LEVEL_COMPONENT_ID))
                .getValue(parentEntity)
        ];
        uint256[] memory equippedItems = ItemsEquippedComponent(
            _gameRegistry.getComponent(ITEMS_EQUIPPED_COMPONENT_ID)
        ).getValue(parentEntity);
        // Pull current equipped items of ship or initialize new array if no data exists
        if (equippedItems.length > 0) {
            return equippedItems;
        } else {
            return new uint256[](slotCount);
        }
    }

    /**
     * @dev Function to override with custom validation logic
     * @param parentEntity A packed tokenId and address for a parent entity which equips items
     * @param item Item params which specify entity, slot type, and slot index to remove
     */
    function _isItemEquippable(
        uint256 parentEntity,
        Item calldata item
    ) internal virtual returns (bool);

    /**
     * @dev Returns boolean representing if account is the owner of parent
     */
    function _isParentOwner(
        address account,
        uint256 parentEntity
    ) internal view returns (bool) {
        (address parentContract, uint256 parentTokenId) = EntityLibrary
            .entityToToken(parentEntity);
        return IERC721(parentContract).ownerOf(parentTokenId) == account;
    }

    /**
     * @dev Reverts if an item is not safe to equip to parent
     */
    function _requireValidItem(
        address account,
        uint256 parentEntity,
        uint256 existingItemEntity,
        Item calldata item
    ) internal {
        (address tokenContract, uint256 tokenId) = EntityLibrary.entityToToken(
            item.itemEntity
        );

        if (tokenContract != _getSystem(GAME_ITEMS_ID)) {
            revert UnauthorizedItem(tokenContract, tokenId);
        }

        // Check if parent is owner of item
        if (IERC1155(tokenContract).balanceOf(account, tokenId) == 0) {
            revert InvalidBalance(tokenId);
        }

        // Check if valid slot index for parent
        uint256 slotCount = getSlotCount(parentEntity, item.slotType);
        if (slotCount <= item.slotIndex) {
            revert InvalidSlotIndex(slotCount, item.slotIndex);
        }

        // Check if slot is occupied; if so it must match existingItemEntity
        uint256[] memory slots = _getItems(parentEntity);
        if (
            slots[item.slotIndex] != 0 &&
            slots[item.slotIndex] != existingItemEntity
        ) {
            revert InvalidSlot(slots[item.slotIndex], existingItemEntity);
        }

        // If combatmodifiers exist then its equippable
        if (
            CombatModifiersComponent(
                _gameRegistry.getComponent(COMBAT_MODIFIERS_COMPONENT_ID)
            ).has(item.itemEntity) == false
        ) {
            revert InvalidItem(item.itemEntity);
        }

        // Run custom validation checks:
        // > Check that item is valid for parent
        // > Check that slot type is valid for implementor
        if (!_isItemEquippable(parentEntity, item)) {
            revert ItemNonEquippableToParent(parentEntity, item.itemEntity);
        }
    }

    /**
     * @dev Safely sets an item to parent entity at slotType and slotIndex
     */
    function _setItem(
        address account,
        uint256 parentEntity,
        uint256 existingItemEntity,
        Item calldata item
    ) internal {
        uint256[] memory currentSlots = _getItems(parentEntity);

        // Validate item and parent are compatible
        _requireValidItem(account, parentEntity, existingItemEntity, item);

        (address tokenContract, uint256 tokenId) = EntityLibrary.entityToToken(
            item.itemEntity
        );

        // Burn the item when storing it in a slot
        ERC1155Burnable(tokenContract).burn(account, tokenId, 1);

        // Set item into the array and write to ItemsEquippedComponent
        currentSlots[item.slotIndex] = item.itemEntity;
        ItemsEquippedComponent(
            _gameRegistry.getComponent(ITEMS_EQUIPPED_COMPONENT_ID)
        ).setValue(parentEntity, currentSlots);
    }

    /**
     * @dev Removes and mints an item from parent entity at slotType if present
     */
    function _removeItem(
        address,
        uint256 parentEntity,
        Item memory item
    ) internal {
        uint256[] memory slots = _getItems(parentEntity);

        // Check equipped slot at slotIndex
        if (
            slots[item.slotIndex] == 0 ||
            slots[item.slotIndex] != item.itemEntity
        ) {
            revert InvalidItem(item.itemEntity);
        }

        // Remove item from slots and write to ItemsEquippedComponent
        delete slots[item.slotIndex];
        ItemsEquippedComponent(
            _gameRegistry.getComponent(ITEMS_EQUIPPED_COMPONENT_ID)
        ).setValue(parentEntity, slots);
    }
}
