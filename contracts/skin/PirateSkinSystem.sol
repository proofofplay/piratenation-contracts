// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {IGameItems, ID as GAME_ITEMS_CONTRACT_ID} from "../tokens/gameitems/IGameItems.sol";
import {EquippableComponent, Layout as EquippableComponentLayout, ID as EQUIPPABLE_COMPONENT_ID} from "../generated/components/EquippableComponent.sol";
import {SkinContainerComponent, Layout as SkinContainerComponentLayout, ID as SKIN_CONTAINER_COMPONENT_ID} from "../generated/components/SkinContainerComponent.sol";
import {IsPirateComponent, ID as IS_PIRATE_COMPONENT_ID} from "../generated/components/IsPirateComponent.sol";
import {GameNFTV2Upgradeable} from "../tokens/gamenft/GameNFTV2Upgradeable.sol";
import {IGameRegistry} from "../core/IGameRegistry.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.pirateskinsystem"));

uint256 constant PIRATE_SKIN_GUID = uint256(
    keccak256("game.piratenation.pirate.skin")
);

/**
 * @title PirateSkinSystem
 */
contract PirateSkinSystem is GameRegistryConsumerUpgradeable {
    /** ERRORS */

    /// @notice Not owner of target entity
    error NotOwner();

    /// @notice Zero balance of itemEntity
    error ZeroBalance();

    /// @notice Invalid token contract
    error InvalidTokenContract();

    /// @notice No skin equipped
    error NoSkinEquipped();

    /// @notice Invalid input
    error InvalidInput();

    /// @notice Skin already set
    error SkinAlreadySet();

    /// @notice NotEquippable
    error NotEquippable();

    /// @notice Invalid Pirate Entity
    error InvalidPirateEntity();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * @dev Set, unset, or replace a pirate skin
     * @param pirateEntity pirate entity to set skin for
     * @param itemEntity entity of skin item to set, if zero then unset
     */
    function handleSkin(
        uint256 pirateEntity,
        uint256 itemEntity
    ) public nonReentrant whenNotPaused {
        if (pirateEntity == 0) {
            revert InvalidInput();
        }
        // Get user account
        address account = _getPlayerAccount(_msgSender());
        bool isPirate = IsPirateComponent(
            _gameRegistry.getComponent(IS_PIRATE_COMPONENT_ID)
        ).getValue(pirateEntity);
        if (isPirate == false) {
            revert InvalidPirateEntity();
        }
        // Pirate entity
        (address pirateNft, uint256 pirateTokenId) = EntityLibrary
            .entityToToken(pirateEntity);

        // Check if user is owner of target entity
        if (IERC721(pirateNft).ownerOf(pirateTokenId) != account) {
            revert NotOwner();
        }
        // If itemEntity is 0, unset vanity item, otherwise set or replace vanity item
        if (itemEntity == 0) {
            _unsetSkin(account, pirateEntity);
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
        // Check if skin is equippable to pirate
        _checkEquippable(itemEntity, pirateNft, pirateTokenId);

        SkinContainerComponent skinContainerComponent = SkinContainerComponent(
            _gameRegistry.getComponent(SKIN_CONTAINER_COMPONENT_ID)
        );
        SkinContainerComponentLayout
            memory skinContainerLayout = skinContainerComponent.getLayoutValue(
                pirateEntity
            );
        // Check if PIRATE_SKIN_GUID is already set and replace it, otherwise add it
        for (uint256 i = 0; i < skinContainerLayout.slotEntities.length; i++) {
            if (skinContainerLayout.slotEntities[i] == PIRATE_SKIN_GUID) {
                // Check if same skin is already set
                if (skinContainerLayout.skinEntities[i] == itemEntity) {
                    revert SkinAlreadySet();
                }
                // Otherwise mint back the previous skin, burn the new skin and overwrite to the new skin
                (, uint256 previousItemTokenId) = EntityLibrary.entityToToken(
                    skinContainerLayout.skinEntities[i]
                );
                gameItems.burn(account, itemTokenId, 1);
                gameItems.mint(account, previousItemTokenId, 1);
                skinContainerLayout.skinEntities[i] = itemEntity;
                skinContainerComponent.setLayoutValue(
                    pirateEntity,
                    skinContainerLayout
                );
                return;
            }
        }
        // Burn new skin and add as new entry
        gameItems.burn(account, itemTokenId, 1);
        uint256[] memory newSlot = new uint256[](1);
        newSlot[0] = PIRATE_SKIN_GUID;
        uint256[] memory newSkin = new uint256[](1);
        newSkin[0] = itemEntity;
        skinContainerComponent.append(
            pirateEntity,
            SkinContainerComponentLayout(newSlot, newSkin)
        );
    }

    /**
     * @dev Internal helper func to check if pirate skin item is equippable to target pirate entity
     * @param itemEntity Entity of item to check
     * @param pirateNft Pirate NFT contract address
     */
    function _checkEquippable(
        uint256 itemEntity,
        address pirateNft,
        uint256
    ) internal view {
        // Check if item is equippable to target entity
        bool isValidEquippable;
        EquippableComponentLayout memory equippableLayout = EquippableComponent(
            _gameRegistry.getComponent(EQUIPPABLE_COMPONENT_ID)
        ).getLayoutValue(itemEntity);
        for (
            uint256 i = 0;
            i < equippableLayout.equippableToEntities.length;
            i++
        ) {
            // Enforce that the item is equippable to the target entity
            if (
                _gameRegistry.getSystem(
                    equippableLayout.equippableToEntities[i]
                ) == pirateNft
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
     * @dev Internal helper func to unset pirate skin item for target pirate entity
     * If pirate skin item is not set, revert
     * @param account Account to unset pirate skin item for
     * @param pirateEntity Pirate entity to unset skin item for
     */
    function _unsetSkin(address account, uint256 pirateEntity) internal {
        SkinContainerComponent skinContainerComponent = SkinContainerComponent(
            _gameRegistry.getComponent(SKIN_CONTAINER_COMPONENT_ID)
        );
        SkinContainerComponentLayout
            memory skinContainerLayout = skinContainerComponent.getLayoutValue(
                pirateEntity
            );

        // Check if PIRATE_SKIN_GUID is set and remove it, otherwise revert
        bool isSet;
        uint256 itemEntity;
        for (uint256 i = 0; i < skinContainerLayout.slotEntities.length; i++) {
            if (skinContainerLayout.slotEntities[i] == PIRATE_SKIN_GUID) {
                isSet = true;
                itemEntity = skinContainerLayout.skinEntities[i];
                skinContainerComponent.removeValueAtIndex(pirateEntity, i);
                break;
            }
        }
        // Revert if PIRATE_SKIN_GUID is not set
        if (isSet == false || itemEntity == 0) {
            revert NoSkinEquipped();
        }
        // Mint back to user
        (address itemTokenContract, uint256 itemTokenId) = EntityLibrary
            .entityToToken(itemEntity);
        IGameItems(itemTokenContract).mint(account, itemTokenId, 1);
    }
}
