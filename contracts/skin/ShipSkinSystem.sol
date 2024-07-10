// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {TEMPLATE_ID_TRAIT_ID} from "../Constants.sol";
import {IGameItems, ID as GAME_ITEMS_CONTRACT_ID} from "../tokens/gameitems/IGameItems.sol";
import {EquippableComponent, Layout as EquippableComponentLayout, ID as EQUIPPABLE_COMPONENT_ID} from "../generated/components/EquippableComponent.sol";
import {SkinContainerComponent, Layout as SkinContainerComponentLayout, ID as SKIN_CONTAINER_COMPONENT_ID} from "../generated/components/SkinContainerComponent.sol";
import {IShipSkinSystem, ID} from "./IShipSkinSystem.sol";
import {MixinComponent, Layout as MixinComponentLayout, ID as MIXIN_COMPONENT_ID} from "../generated/components/MixinComponent.sol";

import {ID as SHIP_NFT_ID} from "../tokens/shipnft/ShipNFT.sol";

uint256 constant SHIP_SKIN_GUID = uint256(
    keccak256("game.piratenation.ship.skin")
);

/**
 * @title ShipSkinSystem
 */
contract ShipSkinSystem is GameRegistryConsumerUpgradeable, IShipSkinSystem {
    /** ERRORS */

    /// @notice Not owner of target entity
    error NotOwner();

    /// @notice Zero balance of itemEntity
    error ZeroBalance();

    /// @notice Invalid token contract
    error InvalidTokenContract();

    /// @notice Invalid vanity item
    error InvalidSkin();

    /// @notice Skin already equipped
    error SkinAlreadyEquipped();

    /// @notice No skin equipped
    error NoSkinEquipped();

    /// @notice Invalid input
    error InvalidInput();

    /// @notice Skin already set
    error SkinAlreadySet();

    /// @notice NotEquippable
    error NotEquippable();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * @dev Set, unset, or replace a ship skin
     * @param shipEntity ship entity to set skin for
     * @param itemEntity entity of skin item to set, if zero then unset
     */
    function handleSkin(
        uint256 shipEntity,
        uint256 itemEntity
    ) public override nonReentrant whenNotPaused {
        if (shipEntity == 0) {
            revert InvalidInput();
        }
        // Get user account
        address account = _getPlayerAccount(_msgSender());
        // Ship entity
        (address shipNft, uint256 shipTokenId) = EntityLibrary.entityToToken(
            shipEntity
        );
        if (shipNft != _gameRegistry.getSystem(SHIP_NFT_ID)) {
            revert InvalidTokenContract();
        }
        // Check if user is owner of target entity
        if (IERC721(shipNft).ownerOf(shipTokenId) != account) {
            revert NotOwner();
        }
        // If itemEntity is 0, unset vanity item, otherwise set or replace vanity item
        if (itemEntity == 0) {
            _unsetSkin(account, shipEntity);
            return;
        }
        // Item entity
        (address itemTokenContract, uint256 itemTokenId) = EntityLibrary
            .entityToToken(itemEntity);
        if (
            itemTokenContract != _gameRegistry.getSystem(GAME_ITEMS_CONTRACT_ID)
        ) {
            revert InvalidTokenContract();
        }
        // Check if owner has the itemEntity
        IGameItems gameItems = IGameItems(itemTokenContract);
        if (gameItems.balanceOf(account, itemTokenId) == 0) {
            revert ZeroBalance();
        }
        // Check if skin is equippable to ship
        _checkEquippable(itemEntity, shipNft, shipTokenId);

        SkinContainerComponent skinContainerComponent = SkinContainerComponent(
            _gameRegistry.getComponent(SKIN_CONTAINER_COMPONENT_ID)
        );
        SkinContainerComponentLayout
            memory skinContainerLayout = skinContainerComponent.getLayoutValue(
                shipEntity
            );
        // Check if SHIP_SKIN_GUID is already set and replace it, otherwise add it
        for (uint256 i = 0; i < skinContainerLayout.slotEntities.length; i++) {
            if (skinContainerLayout.slotEntities[i] == SHIP_SKIN_GUID) {
                // Check if same skin is already set
                if (skinContainerLayout.skinEntities[i] == itemEntity) {
                    revert SkinAlreadySet();
                }
                // Otherwise mint back the previous skin, burn the new skin and overwrite to the new skin
                (, uint256 previousItemTokenId) = EntityLibrary.entityToToken(
                    skinContainerLayout.skinEntities[i]
                );
                gameItems.mint(account, previousItemTokenId, 1);
                gameItems.burn(account, itemTokenId, 1);
                skinContainerLayout.skinEntities[i] = itemEntity;
                skinContainerComponent.setLayoutValue(
                    shipEntity,
                    skinContainerLayout
                );
                return;
            }
        }
        // Burn new skin and add as new entry
        gameItems.burn(account, itemTokenId, 1);
        uint256[] memory newSlot = new uint256[](1);
        newSlot[0] = SHIP_SKIN_GUID;
        uint256[] memory newSkin = new uint256[](1);
        newSkin[0] = itemEntity;
        skinContainerComponent.append(
            shipEntity,
            SkinContainerComponentLayout(newSlot, newSkin)
        );
    }

    /**
     * @dev Internal helper func to check if ship skin item is equippable to target ship entity
     * @param itemEntity Entity of item to check
     * @param shipNft Ship NFT contract address
     * @param shipTokenId Ship NFT token ID
     */
    function _checkEquippable(
        uint256 itemEntity,
        address shipNft,
        uint256 shipTokenId
    ) internal view {
        // Check if item is equippable to target entity
        bool isValidEquippable;
        EquippableComponentLayout memory equippableLayout = EquippableComponent(
            _gameRegistry.getComponent(EQUIPPABLE_COMPONENT_ID)
        ).getLayoutValue(itemEntity);
        uint256 shipMixin = MixinComponent(
            _gameRegistry.getComponent(MIXIN_COMPONENT_ID)
        ).getLayoutValue(
            EntityLibrary.tokenToEntity(shipNft, shipTokenId)
        ).value[0];
        for (
            uint256 i = 0;
            i < equippableLayout.equippableToEntities.length;
            i++
        ) {
            // Enforce that the item is equippable to the target entity
            if (
                equippableLayout.equippableToEntities[i] ==
                shipMixin
            ) {
                isValidEquippable = true;
                break;
            }
        }
        if (isValidEquippable == false) {
            revert NotEquippable();
        }
    }

    /**
     * @dev Internal helper func to unset ship skin item for target ship entity
     * If ship skin item is not set, revert
     * @param account Account to unset ship skin item for
     * @param shipEntity Ship entity to unset skin item for
     */
    function _unsetSkin(address account, uint256 shipEntity) internal {
        SkinContainerComponent skinContainerComponent = SkinContainerComponent(
            _gameRegistry.getComponent(SKIN_CONTAINER_COMPONENT_ID)
        );
        SkinContainerComponentLayout
            memory skinContainerLayout = skinContainerComponent.getLayoutValue(
                shipEntity
            );

        // Check if SHIP_SKIN_GUID is set and remove it, otherwise revert
        bool isSet;
        uint256 itemEntity;
        for (uint256 i = 0; i < skinContainerLayout.slotEntities.length; i++) {
            if (skinContainerLayout.slotEntities[i] == SHIP_SKIN_GUID) {
                isSet = true;
                itemEntity = skinContainerLayout.skinEntities[i];
                skinContainerComponent.removeValueAtIndex(shipEntity, i);
                break;
            }
        }
        // Revert if SHIP_SKIN_GUID is not set
        if (isSet == false || itemEntity == 0) {
            revert NoSkinEquipped();
        }
        // Mint back to user
        (address itemTokenContract, uint256 itemTokenId) = EntityLibrary
            .entityToToken(itemEntity);
        IGameItems(itemTokenContract).mint(account, itemTokenId, 1);
    }
}
