// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

import {COMBAT_MODIFIERS_TRAIT_ID, EQUIPMENT_TYPE_TRAIT_ID, GAME_ITEMS_CONTRACT_ROLE} from "../Constants.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {ITraitsProvider} from "../interfaces/ITraitsProvider.sol";
import {Item, IEquippable} from "./IEquippable.sol";
import {ItemsEquippedComponent, ID as ITEMS_EQUIPPED_COMPONENT_ID} from "../generated/components/ItemsEquippedComponent.sol";

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
    error InvalidItem(uint256 parentEntity, uint256 itemEntity);

    /// @notice Item cannot be equipped by invalid parent
    error InvalidParent();

    /// @notice Desired slot is invalid for item
    error InvalidSlot(uint256 slottedItemEntity, uint256 replaceItemEntity);

    /// @notice Desired slot index is invalid
    error InvalidSlotIndex(uint256 index);

    /** EXTERNAL **/

    /**
     * @inheritdoc IEquippable
     */
    function getCombatModifiers(
        uint256 parentEntity
    ) external view override returns (int256[] memory) {
        ITraitsProvider traitsProvider = _traitsProvider();

        // Get all slot types
        uint256[] memory slotTypes = _getSlotTypes(parentEntity);

        // Loop through slot types and get equipment loadout for each
        int256[] memory combatModifiers = new int256[](5);
        for (uint256 i = 0; i < slotTypes.length; i++) {
            uint256[] memory equipment = _getItems(
                parentEntity,
                slotTypes[i],
                traitsProvider
            );
            for (uint256 j = 0; j < equipment.length; j++) {
                // Get combat modifiers for item
                int256[] memory itemCombatModifiers = _getItemCombatModifiers(
                    equipment[j],
                    traitsProvider
                );

                // Add item combat modifiers to parent combat modifiers
                for (uint256 k = 0; k < itemCombatModifiers.length; k++) {
                    combatModifiers[k] += itemCombatModifiers[k];
                }
            }
        }

        return combatModifiers;
    }

    /**
     * @inheritdoc IEquippable
     */
    function getItems(
        uint256 parentEntity,
        uint256 slotType
    ) external view returns (uint256[] memory) {
        return _getItems(parentEntity, slotType, _traitsProvider());
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
            _removeItem(account, parentEntity, items[i], _traitsProvider());
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
        uint256 parentEntity,
        uint256 slotType,
        ITraitsProvider traitsProvider
    ) internal view returns (uint256[] memory) {
        (address tokenContract, uint256 tokenId) = EntityLibrary.entityToToken(
            parentEntity
        );

        // Pull current slots from trait provider or initialize new array if no trait exists
        return
            traitsProvider.hasTrait(tokenContract, tokenId, slotType)
                ? traitsProvider.getTraitUint256Array(
                    tokenContract,
                    tokenId,
                    slotType
                )
                : new uint256[](getSlotCount(parentEntity, slotType));
    }

    /**
     * @dev Returns the combat modifiers for an item
     */
    function _getItemCombatModifiers(
        uint256 itemEntity,
        ITraitsProvider traitsProvider
    ) internal view returns (int256[] memory) {
        (address tokenContract, uint256 tokenId) = EntityLibrary.entityToToken(
            itemEntity
        );

        // Return combat modifiers for item if it has them
        return
            traitsProvider.hasTrait(
                tokenContract,
                tokenId,
                COMBAT_MODIFIERS_TRAIT_ID
            )
                ? traitsProvider.getTraitInt256Array(
                    tokenContract,
                    tokenId,
                    COMBAT_MODIFIERS_TRAIT_ID
                )
                : new int256[](5);
    }

    /**
     * @dev Returns the slot types available for a parent entity
     * @param parentEntity A packed tokenId and address for a parent entity which equips items
     */
    function _getSlotTypes(
        uint256 parentEntity
    ) internal view virtual returns (uint256[] memory);

    /**
     * @dev Function to override with custom validation logic
     * @param parentEntity A packed tokenId and address for a parent entity which equips items
     * @param item Item params which specify entity, slot type, and slot index to remove
     * @param traitsProvider Reference to TraitsProvider system for reading traits
     */
    function _isItemEquippable(
        uint256 parentEntity,
        Item calldata item,
        ITraitsProvider traitsProvider
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
        Item calldata item,
        ITraitsProvider traitsProvider
    ) internal {
        (address tokenContract, uint256 tokenId) = EntityLibrary.entityToToken(
            item.itemEntity
        );

        // Ensure item a burnable game item; for now must be ERC1155
        // Also requires item to implement TraitConsumer which aids in reading traits
        if (_hasAccessRole(GAME_ITEMS_CONTRACT_ROLE, tokenContract) == false) {
            revert InvalidItem(parentEntity, item.itemEntity);
        }

        // Check if parent is owner of item
        if (IERC1155(tokenContract).balanceOf(account, tokenId) == 0) {
            revert InvalidItem(parentEntity, item.itemEntity);
        }

        // Check if valid slot index for parent
        if (getSlotCount(parentEntity, item.slotType) <= item.slotIndex) {
            revert InvalidSlotIndex(item.slotIndex);
        }

        // Check if slot is occupied; if so it must match existingItemEntity
        uint256[] memory slots = _getItems(
            parentEntity,
            item.slotType,
            traitsProvider
        );
        if (
            slots[item.slotIndex] != 0 &&
            slots[item.slotIndex] != existingItemEntity
        ) {
            revert InvalidSlot(slots[item.slotIndex], existingItemEntity);
        }

        // Check item has `equipment_type` trait
        if (
            !traitsProvider.hasTrait(
                tokenContract,
                tokenId,
                EQUIPMENT_TYPE_TRAIT_ID
            )
        ) {
            revert InvalidItem(parentEntity, item.itemEntity);
        }

        // Run custom validation checks:
        // > Check that item is valid for parent
        // > Check that slot type is valid for implementor
        if (!_isItemEquippable(parentEntity, item, traitsProvider)) {
            revert InvalidItem(parentEntity, item.itemEntity);
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
        ITraitsProvider traitsProvider = _traitsProvider();
        uint256[] memory currentSlots = _getItems(
            parentEntity,
            item.slotType,
            traitsProvider
        );

        // Validate item and parent are compatible
        _requireValidItem(
            account,
            parentEntity,
            existingItemEntity,
            item,
            traitsProvider
        );

        (address tokenContract, uint256 tokenId) = EntityLibrary.entityToToken(
            item.itemEntity
        );

        // Burn the item when storing it in a slot
        ERC1155Burnable(tokenContract).burn(account, tokenId, 1);

        // For now we do not mint items back to the user, but we can someday
        // Check if slot is occupied and remove it if so
        // if (currentSlots[item.slotIndex] != 0) {
        //     _removeItem(
        //         account,
        //         parentEntity,
        //         Item({
        //             itemEntity: currentSlots[item.slotIndex],
        //             slotType: item.slotType,
        //             slotIndex: item.slotIndex
        //         }),
        //         traitsProvider
        //     );
        // }

        // Set item in traits provider; for now this clobbers any equipped item
        currentSlots[item.slotIndex] = item.itemEntity;
        (tokenContract, tokenId) = EntityLibrary.entityToToken(parentEntity);
        traitsProvider.setTraitUint256Array(
            tokenContract,
            tokenId,
            item.slotType,
            currentSlots
        );
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
        Item memory item,
        ITraitsProvider traitsProvider
    ) internal {
        uint256[] memory slots = _getItems(
            parentEntity,
            item.slotType,
            traitsProvider
        );

        // Check equipped slot at slotIndex
        if (
            slots[item.slotIndex] == 0 ||
            slots[item.slotIndex] != item.itemEntity
        ) {
            revert InvalidItem(parentEntity, item.itemEntity);
        }

        // Remove item from slots
        delete slots[item.slotIndex];

        (address tokenContract, uint256 tokenId) = EntityLibrary.entityToToken(
            parentEntity
        );
        traitsProvider.setTraitUint256Array(
            tokenContract,
            tokenId,
            item.slotType,
            slots
        );
        ItemsEquippedComponent(
            _gameRegistry.getComponent(ITEMS_EQUIPPED_COMPONENT_ID)
        ).setValue(parentEntity, slots);

        // Default behavior is not to mint the item back to caller
        // (tokenContract, tokenId) = EntityLibrary.entityToToken(item.itemEntity);
        // IGameItems(tokenContract).mint(account, tokenId, 1);
    }
}
