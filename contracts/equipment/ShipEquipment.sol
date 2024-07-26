// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {EntityLibrary} from "../core/EntityLibrary.sol";
import {Equippable} from "./Equippable.sol";
import {EquipmentType, Item} from "./IEquippable.sol";
import {MixinComponent, ID as MIXIN_COMPONENT_ID} from "../generated/components/MixinComponent.sol";
import {ItemSlotsComponent, Layout as ItemSlotsComponentLayout, ID as ITEM_SLOTS_COMPONENT_ID} from "../generated/components/ItemSlotsComponent.sol";
import {IsShipComponent, ID as IS_SHIP_COMPONENT_ID} from "../generated/components/IsShipComponent.sol";
import {CombatModifiersComponent, ID as COMBAT_MODIFIERS_COMPONENT_ID} from "../generated/components/CombatModifiersComponent.sol";

// Constants
uint256 constant ID = uint256(keccak256("game.piratenation.shipequipment"));
uint256 constant SHIP_CORE_SLOT_TYPE = uint256(
    keccak256("equipment.ship.core")
);

contract ShipEquipment is Equippable {
    /** SETUP **/

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /** EXTERNAL **/

    /**
     * @dev Return the number of item slots a parent entity has for a specific slot type
     * @param parentEntity A packed tokenId and address for the parent entity which will equip the item
     */
    function getSlotCount(
        uint256 parentEntity,
        uint256
    ) public view override returns (uint256) {
        // Get mixin id for the ship
        uint256 mixinId = MixinComponent(
            _gameRegistry.getComponent(MIXIN_COMPONENT_ID)
        ).getValue(parentEntity)[0];
        // Get ItemSlotsComponent for the mixin
        uint256 itemSlotCount = ItemSlotsComponent(
            _gameRegistry.getComponent(ITEM_SLOTS_COMPONENT_ID)
        ).getValue(mixinId);

        return itemSlotCount;
    }

    /** INTERNAL **/

    /**
     * @dev Function to override with custom validation logic
     */
    function _isItemEquippable(
        uint256 parentEntity,
        Item calldata item
    ) internal view override returns (bool) {
        // Check that parent is a ship
        // Get mixin id for the ship
        uint256 mixinId = MixinComponent(
            _gameRegistry.getComponent(MIXIN_COMPONENT_ID)
        ).getValue(parentEntity)[0];
        bool isShip = IsShipComponent(
            _gameRegistry.getComponent(IS_SHIP_COMPONENT_ID)
        ).getValue(mixinId);
        if (isShip == false) {
            return false;
        }

        // If combatmodifiers exist then its equippable
        if (
            CombatModifiersComponent(
                _gameRegistry.getComponent(COMBAT_MODIFIERS_COMPONENT_ID)
            ).has(item.itemEntity) == false
        ) {
            return false;
        }

        return true;
    }
}
