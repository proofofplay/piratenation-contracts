// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {TEMPLATE_ID_TRAIT_ID} from "../Constants.sol";
import {IGameItems, ID as GAME_ITEMS_CONTRACT_ID} from "../tokens/gameitems/IGameItems.sol";
import {EquippableComponent, Layout as EquippableComponentLayout, ID as EQUIPPABLE_COMPONENT_ID} from "../generated/components/EquippableComponent.sol";
import {SkinContainerComponent, Layout as SkinContainerComponentLayout, ID as SKIN_CONTAINER_COMPONENT_ID} from "../generated/components/SkinContainerComponent.sol";
import {IComponent} from "../core/components/IComponent.sol";

import {IAccountSkinSystem, ID} from "./IAccountSkinSystem.sol";

/**
 * @title AccountSkinSystem
 * @dev Skin system for non-nft vanity setting and unsetting on accounts
 */
contract AccountSkinSystem is
    GameRegistryConsumerUpgradeable,
    IAccountSkinSystem
{
    /** ERRORS */

    /// @notice Zero balance of itemEntity
    error ZeroBalance();

    /// @notice Invalid token contract
    error InvalidTokenContract();

    /// @notice Target does not have a vanity item equipped
    error TargetDoesNotHaveVanityEquipped();

    /// @notice NotEquippable
    error NotEquippable(uint256 namespaceGuid);

    /// @notice Invalid input
    error InvalidInput();

    /// @notice Skin already set
    error SkinAlreadySet();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * @dev Set, unset, replace skin item for target entity
     * @param itemEntity entity of vanity item to set, if zero then unset
     * @param namespaceGuid namespace guid of object being skinned
     */
    function handleVanity(
        uint256 itemEntity,
        uint256 namespaceGuid
    ) public override nonReentrant whenNotPaused {
        if (namespaceGuid == 0) {
            revert InvalidInput();
        }
        // Get user account
        address account = _getPlayerAccount(_msgSender());
        // If itemEntity is 0, unset vanity item, otherwise set or replace vanity item
        if (itemEntity == 0) {
            _unsetVanity(account, namespaceGuid);
            return;
        }
        // Check if item is equippable to target entity by way of namespace guid
        _checkEquippable(itemEntity, namespaceGuid);

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

        SkinContainerComponent skinContainerComponent = SkinContainerComponent(
            _gameRegistry.getComponent(SKIN_CONTAINER_COMPONENT_ID)
        );
        SkinContainerComponentLayout
            memory skinContainerLayout = skinContainerComponent.getLayoutValue(
                EntityLibrary.addressToEntity(account)
            );
        // Check if namespaceGuid is already set and replace it, otherwise add it
        for (uint256 i = 0; i < skinContainerLayout.slotEntities.length; i++) {
            if (skinContainerLayout.slotEntities[i] == namespaceGuid) {
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
                    EntityLibrary.addressToEntity(account),
                    skinContainerLayout
                );
                return;
            }
        }
        // Burn new skin and add as new entry
        gameItems.burn(account, itemTokenId, 1);
        uint256[] memory newSlot = new uint256[](1);
        newSlot[0] = namespaceGuid;
        uint256[] memory newSkin = new uint256[](1);
        newSkin[0] = itemEntity;
        skinContainerComponent.append(
            EntityLibrary.addressToEntity(account),
            SkinContainerComponentLayout(newSlot, newSkin)
        );
    }

    /**
     * @dev Internal helper func to check if skin item is equippable to target entity
     * @param itemEntity Entity of item to check
     * @param namespaceGuid Namespace guid of object being skinned
     */
    function _checkEquippable(
        uint256 itemEntity,
        uint256 namespaceGuid
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
            if (equippableLayout.equippableToEntities[i] == namespaceGuid) {
                isValidEquippable = true;
                break;
            }
        }
        if (isValidEquippable == false) {
            revert NotEquippable(namespaceGuid);
        }
    }

    /**
     * @dev Internal helper func to unset vanity item for target entity
     * If vanity item is not set, revert
     * @param account Account to unset vanity item for
     * @param namespaceGuidToUnset Namespace guid of object being unskinned
     */
    function _unsetVanity(
        address account,
        uint256 namespaceGuidToUnset
    ) internal {
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        SkinContainerComponent skinContainerComponent = SkinContainerComponent(
            _gameRegistry.getComponent(SKIN_CONTAINER_COMPONENT_ID)
        );
        SkinContainerComponentLayout
            memory skinContainerLayout = skinContainerComponent.getLayoutValue(
                accountEntity
            );
        // Check if namespaceGuidToUnset is set and remove it, otherwise revert
        bool isSet;
        uint256 itemEntity;
        for (uint256 i = 0; i < skinContainerLayout.slotEntities.length; i++) {
            if (skinContainerLayout.slotEntities[i] == namespaceGuidToUnset) {
                isSet = true;
                itemEntity = skinContainerLayout.skinEntities[i];
                skinContainerComponent.removeValueAtIndex(accountEntity, i);
                break;
            }
        }
        // Revert if namespaceGuidToUnset is not set
        if (isSet == false || itemEntity == 0) {
            revert TargetDoesNotHaveVanityEquipped();
        }
        // Mint back to user
        (address itemTokenContract, uint256 itemTokenId) = EntityLibrary
            .entityToToken(itemEntity);
        IGameItems(itemTokenContract).mint(account, itemTokenId, 1);
    }
}
