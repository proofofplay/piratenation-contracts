// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Enum describing the kind of items that can be equipped
enum EquipmentType {
    UNDEFINED,
    SHIPS,
    length // This must remain as last member in enum; currently == 2
}

/**
 * Input for setting an item to a slot; may remove any existing items in slot
 * @param itemEntity Entity of item to equip
 * @param slotType Keccak256 identifier of the slot type to equip item to
 * @param slotIndex Slot index to equip item to
 */
struct Item {
    uint256 itemEntity;
    uint256 slotType;
    uint256 slotIndex;
}

/**
 * @title IEquippable
 *
 * IEquippable is an interface for defining how game nft's can be equipped with other entities.
 */
interface IEquippable {
    /**
     * @dev Returns the total combat modifiers given a parent entity's equipment loadout
     * @param parentEntity A packed tokenId and address for a parent entity which equips items
     */
    function getCombatModifiers(
        uint256 parentEntity
    ) external view returns (int256[] memory);

    /**
     * @dev Returns the equipment loadout at a parent entity's slotType, or initializes a new one
     * @param parentEntity A packed tokenId and address for the parent entity which will equip the item
     * @param slotType Keccak256 identifier of the slot type to get equipment loadout for
     */
    function getItems(
        uint256 parentEntity,
        uint256 slotType
    ) external view returns (uint256[] memory);

    /**
     * @dev Return the number of item slots a parent entity has for a specific slot type
     * @param parentEntity A packed tokenId and address for the parent entity which will equip the item
     * @param slotType Keccak256 identifier of the slot type to equip item to return item count for
     */
    function getSlotCount(
        uint256 parentEntity,
        uint256 slotType
    ) external view returns (uint256);

    /**
     * @dev Stores an array of items to equipment slots
     * @param parentEntity A packed tokenId and address for the parent entity which will equip the item
     * @param existingItems Array of existing items that are expected to be overrode
     * @param items Array of params which specify entity, slot type, and slot index to equip to
     */
    function setItems(
        uint256 parentEntity,
        uint256[] calldata existingItems,
        Item[] calldata items
    ) external;

    /**
     * @dev Removes an array of items from equipment slots
     * @param parentEntity A packed tokenId and address for the parent entity which will equip the item
     * @param items Array of params which specify entity, slot type, and slot index to remove from
     */
    function removeItems(uint256 parentEntity, Item[] calldata items) external;
}
