// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {EQUIPMENT_TYPE_TRAIT_ID, IS_SHIP_TRAIT_ID, ITEM_SLOTS_TRAIT_ID} from "../Constants.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {ITraitsProvider} from "../interfaces/ITraitsProvider.sol";
import {ITokenTemplateSystem, ID as TOKEN_TEMPLATE_SYSTEM_ID} from "../tokens/ITokenTemplateSystem.sol";
import {Equippable} from "./Equippable.sol";
import {EquipmentType, Item} from "./IEquippable.sol";

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
     * @param slotType Keccak256 identifier of the slot type to equip item to return item count for
     */
    function getSlotCount(
        uint256 parentEntity,
        uint256 slotType
    ) public view override returns (uint256) {
        ITokenTemplateSystem tokenTemplateSystem = ITokenTemplateSystem(
            _getSystem(TOKEN_TEMPLATE_SYSTEM_ID)
        );

        // Ships only have a single slot type
        if (slotType != SHIP_CORE_SLOT_TYPE) {
            return 0;
        }

        // Get ITEM_SLOTS_TRAIT_ID from TokenTemplateSystem
        (address tokenContract, uint256 tokenId) = EntityLibrary.entityToToken(
            parentEntity
        );
        return
            tokenTemplateSystem.hasTrait(
                tokenContract,
                tokenId,
                ITEM_SLOTS_TRAIT_ID
            )
                ? tokenTemplateSystem.getTraitUint256(
                    tokenContract,
                    tokenId,
                    ITEM_SLOTS_TRAIT_ID
                )
                : 0;
    }

    /** INTERNAL **/

    /**
     * @dev Returns the slot types available for a parent entity
     */
    function _getSlotTypes(
        uint256
    ) internal pure override returns (uint256[] memory) {
        uint256[] memory slotTypes = new uint256[](1);
        slotTypes[0] = SHIP_CORE_SLOT_TYPE;
        return slotTypes;
    }

    /**
     * @dev Function to override with custom validation logic
     */
    function _isItemEquippable(
        uint256 parentEntity,
        Item calldata item,
        ITraitsProvider traitsProvider
    ) internal view override returns (bool) {
        (address tokenContract, uint256 tokenId) = EntityLibrary.entityToToken(
            parentEntity
        );

        // Check is valid slot type
        if (item.slotType != SHIP_CORE_SLOT_TYPE) {
            return false;
        }

        // Check that parent is a ship
        if (
            traitsProvider.getTraitBool(
                tokenContract,
                tokenId,
                IS_SHIP_TRAIT_ID
            ) == false
        ) {
            return false;
        }

        // Check if item is equippable by parent
        (tokenContract, tokenId) = EntityLibrary.entityToToken(item.itemEntity);
        if (
            traitsProvider.getTraitUint256(
                tokenContract,
                tokenId,
                EQUIPMENT_TYPE_TRAIT_ID
            ) != uint256(EquipmentType.SHIPS)
        ) {
            return false;
        }

        return true;
    }
}
