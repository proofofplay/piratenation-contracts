// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {GAME_LOGIC_CONTRACT_ROLE, MINTER_ROLE} from "./Constants.sol";
import {GameRegistryConsumerUpgradeable} from "./GameRegistryConsumerUpgradeable.sol";
import {EntityLibrary} from "./core/EntityLibrary.sol";
import {IGameItems, ID as GAME_ITEMS_CONTRACT_ID} from "./tokens/gameitems/IGameItems.sol";
import {DustValueComponent, ID as DUST_VALUE_COMPONENT_ID} from "./generated/components/DustValueComponent.sol";
import {EntityBaseComponent, ID as ENTITY_BASE_COMPONENT_ID} from "./generated/components/EntityBaseComponent.sol";
import {ShipNFT, ID as SHIP_NFT_ID} from "./tokens/shipnft/ShipNFT.sol";
import {MixinComponent, ID as MIXIN_COMPONENT_ID} from "./generated/components/MixinComponent.sol";
import {IsShipComponent, ID as IS_SHIP_COMPONENT_ID} from "./generated/components/IsShipComponent.sol";
import {ShipEquipment, ID as SHIP_EQUIPMENT_ID} from "./equipment/ShipEquipment.sol";
import {SkinContainerComponent, Layout as SkinContainerComponentLayout, ID as SKIN_CONTAINER_COMPONENT_ID} from "./generated/components/SkinContainerComponent.sol";
import {LevelComponent, ID as LEVEL_COMPONENT_ID} from "./generated/components/LevelComponent.sol";
import {Uint256ArrayComponent, ID as UINT256_ARRAY_COMPONENT_ID} from "./generated/components/Uint256ArrayComponent.sol";
import {SHIP_SKIN_GUID} from "./skin/ShipSkinSystem.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.dustsystem"));

// @notice The global id for the dust item
uint256 constant DUST_ITEM_GLOBAL_ID = uint256(
    keccak256("game.piratenation.global.dustitem")
);

// @notice The global id for the ship level dust amount array
uint256 constant SHIP_LEVEL_DUST_AMOUNT_GLOBAL_ID = uint256(
    keccak256("game.piratenation.global.shipleveldustamount")
);

/** ERRORS */

/// @notice Error when user doesn't own the items
error NotEnoughItems(uint256 itemId, uint256 required, uint256 owned);

/// @notice Error when dust value is zero
error ZeroDustValue(uint256 itemId);

/// @notice Error when quantity is zero
error ZeroQuantity();

/// @notice Error when length of itemIds and quantities is not the same
error InvalidLength();

/// @notice No dust item found
error NoDustItemFound();

/// @notice Not a ship
error NotAShip();

/// @notice Not owner of ship
error NotOwner();

/**
 * @title DustSystem
 * @notice System for dusting items and receiving dust tokens based on DustValueComponent
 */
contract DustSystem is GameRegistryConsumerUpgradeable {
    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * Dust items and receive dust tokens based on their dust value
     *
     * @param itemEntityIds The item entity IDs to dust
     * @param quantities The quantity of items to dust
     */
    function dustItems(
        uint256[] calldata itemEntityIds,
        uint256[] calldata quantities
    ) external whenNotPaused nonReentrant {
        if (quantities.length == 0 || itemEntityIds.length == 0) {
            revert InvalidLength();
        }
        // Get the player account
        address account = _getPlayerAccount(_msgSender());

        // Get the GameItems contract
        IGameItems gameItems = IGameItems(_getSystem(GAME_ITEMS_CONTRACT_ID));

        // Get the dust item entity id
        uint256 entityId = EntityBaseComponent(
            _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
        ).getValue(DUST_ITEM_GLOBAL_ID);
        // Get the dust item token id
        (, uint256 dustItemTokenId) = EntityLibrary.entityToToken(entityId);
        // Check if the dust item exists
        if (dustItemTokenId == 0) {
            revert NoDustItemFound();
        }
        // Loop through each item entity id and quantity
        for (uint256 i = 0; i < itemEntityIds.length; i++) {
            uint256 itemEntityId = itemEntityIds[i];
            uint256 quantity = quantities[i];
            if (quantity == 0 || itemEntityId == 0) {
                revert ZeroQuantity();
            }
            // Get the token id for the item
            (, uint256 itemId) = EntityLibrary.entityToToken(itemEntityId);

            // Check if user owns the items
            uint256 balance = gameItems.balanceOf(account, itemId);
            if (balance < quantity) {
                revert NotEnoughItems(itemId, quantity, balance);
            }

            // Get the dust value for this item
            uint256 dustValue = DustValueComponent(
                _gameRegistry.getComponent(DUST_VALUE_COMPONENT_ID)
            ).getValue(itemEntityId);
            if (dustValue == 0) {
                revert ZeroDustValue(itemId);
            }

            // Calculate total dust tokens to mint
            uint256 totalDustTokens = dustValue * quantity;

            // Burn the items from the user
            gameItems.burn(account, itemId, quantity);

            // Mint dust tokens to the user
            gameItems.mint(account, dustItemTokenId, totalDustTokens);
        }
    }

    /**
     * Dust ships and receive dust tokens based on their dust value
     *
     * @param shipEntityIds The ship entity IDs to dust
     */
    function dustShips(
        uint256[] calldata shipEntityIds
    ) external whenNotPaused nonReentrant {
        if (shipEntityIds.length == 0) {
            revert InvalidLength();
        }
        // Get the dust item entity id
        uint256 entityId = EntityBaseComponent(
            _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
        ).getValue(DUST_ITEM_GLOBAL_ID);
        // Get the dust item token id
        (, uint256 dustItemTokenId) = EntityLibrary.entityToToken(entityId);
        // Check if the dust item exists
        if (dustItemTokenId == 0) {
            revert NoDustItemFound();
        }
        ShipEquipment shipEquipment = ShipEquipment(
            _gameRegistry.getSystem(SHIP_EQUIPMENT_ID)
        );
        // Get the player account
        address account = _getPlayerAccount(_msgSender());
        // Get the ship NFT contract
        ShipNFT shipNFT = ShipNFT(_gameRegistry.getSystem(SHIP_NFT_ID));
        // Get the GameItems contract
        IGameItems gameItems = IGameItems(_getSystem(GAME_ITEMS_CONTRACT_ID));
        for (uint256 i = 0; i < shipEntityIds.length; i++) {
            uint256 shipEntityId = shipEntityIds[i];
            if (shipEntityId == 0) {
                revert ZeroQuantity();
            }
            // Get mixin id for the ship
            uint256 mixinId = MixinComponent(
                _gameRegistry.getComponent(MIXIN_COMPONENT_ID)
            ).getValue(shipEntityId)[0];
            if (
                IsShipComponent(
                    _gameRegistry.getComponent(IS_SHIP_COMPONENT_ID)
                ).getValue(mixinId) == false
            ) {
                revert NotAShip();
            }
            // Get the ship id
            (, uint256 shipId) = EntityLibrary.entityToToken(shipEntityId);
            // Get the dust value for this ship
            uint256 dustValue = DustValueComponent(
                _gameRegistry.getComponent(DUST_VALUE_COMPONENT_ID)
            ).getValue(mixinId);
            if (dustValue == 0) {
                revert ZeroDustValue(mixinId);
            }
            // Check if user is owner of target entity
            if (shipNFT.ownerOf(shipId) != account) {
                revert NotOwner();
            }
            // Check if a skin is equipped to the ship, if so, get the dust value for the skin and mint it to the user
            if (
                SkinContainerComponent(
                    _gameRegistry.getComponent(SKIN_CONTAINER_COMPONENT_ID)
                ).getLayoutValue(shipEntityId).slotEntities.length > 0
            ) {
                SkinContainerComponentLayout
                    memory skinContainerLayout = SkinContainerComponent(
                        _gameRegistry.getComponent(SKIN_CONTAINER_COMPONENT_ID)
                    ).getLayoutValue(shipEntityId);

                if (skinContainerLayout.slotEntities[0] == SHIP_SKIN_GUID) {
                    uint256 skinDustValue = DustValueComponent(
                        _gameRegistry.getComponent(DUST_VALUE_COMPONENT_ID)
                    ).getValue(skinContainerLayout.skinEntities[0]);
                    if (skinDustValue != 0) {
                        // Remove the skin from the ship
                        SkinContainerComponent(
                            _gameRegistry.getComponent(
                                SKIN_CONTAINER_COMPONENT_ID
                            )
                        ).removeValueAtIndex(shipEntityId, 0);
                        gameItems.mint(account, dustItemTokenId, skinDustValue);
                    }
                }
            }

            // Check if any items are equipped to the ship and dust them
            uint256[] memory equippedItems = shipEquipment.getItems(
                shipEntityId,
                0
            );
            for (uint256 j = 0; j < equippedItems.length; j++) {
                if (equippedItems[j] != 0) {
                    uint256 equippedItemDustValue = DustValueComponent(
                        _gameRegistry.getComponent(DUST_VALUE_COMPONENT_ID)
                    ).getValue(equippedItems[j]);
                    if (equippedItemDustValue != 0) {
                        gameItems.mint(
                            account,
                            dustItemTokenId,
                            equippedItemDustValue
                        );
                    }
                }
            }
            // Get the level of the ship
            uint256 level = LevelComponent(
                _gameRegistry.getComponent(LEVEL_COMPONENT_ID)
            ).getValue(shipEntityId);
            uint256[] memory shipLevelDustAmounts = Uint256ArrayComponent(
                _gameRegistry.getComponent(UINT256_ARRAY_COMPONENT_ID)
            ).getValue(SHIP_LEVEL_DUST_AMOUNT_GLOBAL_ID);
            if (level > 1) {
                gameItems.mint(
                    account,
                    dustItemTokenId,
                    shipLevelDustAmounts[level]
                );
            }

            // Burn the ship from the user
            shipNFT.burn(shipId);
            // Mint dust tokens to the user
            gameItems.mint(account, dustItemTokenId, dustValue);
        }
    }
}
