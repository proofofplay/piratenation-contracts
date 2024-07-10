// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {ID, IShipWrightSystem, UpgradeShipInput} from "./IShipWrightSystem.sol";
import "../GameRegistryConsumerUpgradeable.sol";

import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {LootArrayComponentLibrary} from "../loot/LootArrayComponentLibrary.sol";
import {IGameCurrency} from "../tokens/IGameCurrency.sol";
import {ILootSystem} from "../loot/ILootSystem.sol";
import {ShipNFT, ID as SHIP_NFT_ID} from "../tokens/shipnft/ShipNFT.sol";
import {SHIP_SKIN_GUID} from "../skin/ShipSkinSystem.sol";
import {SceneObjectGameItemComponent, ID as SCENE_OBJECT_GAME_ITEM_COMPONENT_ID} from "../generated/components/SceneObjectGameItemComponent.sol";
import {SkinContainerComponent, Layout as SkinContainerComponentLayout, ID as SKIN_CONTAINER_COMPONENT_ID} from "../generated/components/SkinContainerComponent.sol";
import {PublicUseComponent, ID as PUBLIC_USE_COMPONENT_ID} from "../generated/components/PublicUseComponent.sol";
import {OwnerComponent, ID as OWNER_COMPONENT_ID} from "../generated/components/OwnerComponent.sol";
import {ShipWrightComponent, Layout as ShipWrightComponentLayout, ID as SHIP_WRIGHT_COMPONENT_ID} from "../generated/components/ShipWrightComponent.sol";
import {SceneObjectParentComponent, ID as SCENE_OBJECT_PARENT_COMPONENT_ID} from "../generated/components/SceneObjectParentComponent.sol";
import {LevelComponent, ID as LEVEL_COMPONENT_ID} from "../generated/components/LevelComponent.sol";
import {ShipPlanComponent, Layout as ShipPlanComponentLayout, ID as SHIP_PLAN_COMPONENT_ID} from "../generated/components/ShipPlanComponent.sol";
import {ShipTypeComponent, ID as SHIP_TYPE_COMPONENT_ID} from "../generated/components/ShipTypeComponent.sol";
import {LootArrayComponent, Layout as LootArrayComponentLayout, ID as LOOT_ARRAY_COMPONENT_ID} from "../generated/components/LootArrayComponent.sol";
import {UpgradeableItemComponent, Layout as UpgradeableItemComponentLayout, ID as UPGRADEABLE_ITEM_COMPONENT_ID} from "../generated/components/UpgradeableItemComponent.sol";
import {ShipWrightCooldownComponent, Layout as ShipWrightCooldownComponentLayout, ID as SHIP_WRIGHT_COOLDOWN_COMPONENT_ID} from "../generated/components/ShipWrightCooldownComponent.sol";
import {ShipTypeMergeableComponent, ID as SHIP_TYPE_MERGEABLE_COMPONENT_ID} from "../generated/components/ShipTypeMergeableComponent.sol";
import {ShipWrightPlacedComponent, Layout as ShipWrightPlacedComponentLayout, ID as SHIPWRIGHT_PLACED_COMPONENT_ID} from "../generated/components/ShipWrightPlacedComponent.sol";
import {MixinComponent, Layout as MixinComponentLayout, ID as MIXIN_COMPONENT_ID} from "../generated/components/MixinComponent.sol";

/**
 * @title ShipWrightSystem
 */
contract ShipWrightSystem is
    IShipWrightSystem,
    GameRegistryConsumerUpgradeable
{
    /** ERRORS **/

    /// @notice Not owner of target entity
    error NotShipOwner();

    /// @notice Zero balance of itemEntity
    error ShipWrightNotFound(uint256 entity);

    /// @notice Not a valid ShipWright
    error NotValidShipWright(uint256 entity);

    /// @notice Invalid ShipPlan
    error InvalidShipPlan();

    /// @notice Invalid ShipLevel
    error InvalidShipLevel();

    /// @notice Skin still equipped
    error SkinEquipped();

    /// @notice ShipWright set private
    error ShipWrightPrivate();

    /// @notice Invalid ship types
    error InvalidShipTypes();

    /// @notice ShipWright still in cooldown
    error StillInCooldown();

    /// @notice Not a valid status
    error NotValidStatus();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * @dev Ship merging functionality of ShipWright
     * @param input Input struct containing all the required inputs for the merging functionality
     */
    function upgradeShip(
        UpgradeShipInput calldata input
    ) external override whenNotPaused nonReentrant {
        address caller = _getPlayerAccount(_msgSender());
        uint256 itemEntity = _getObjectEntity(input.instanceEntity);
        if (itemEntity == 0) {
            revert ShipWrightNotFound(input.instanceEntity);
        }
        // Check valid call to ShipWright
        address shipWrightOwner = _checkValidShipWrightCall(
            input.instanceEntity,
            caller
        );
        // Check that instanceEntity is a ShipWright
        ShipWrightComponentLayout memory shipWrightLayout = ShipWrightComponent(
            _gameRegistry.getComponent(SHIP_WRIGHT_COMPONENT_ID)
        ).getLayoutValue(itemEntity);
        if (shipWrightLayout.repairCooldownSeconds == 0) {
            revert NotValidShipWright(itemEntity);
        }

        // Check merging-cooldown has passed
        if (
            ShipWrightCooldownComponent(
                _gameRegistry.getComponent(SHIP_WRIGHT_COOLDOWN_COMPONENT_ID)
            ).getLayoutValue(input.instanceEntity).mergeTimestamp +
                shipWrightLayout.mergeCooldownSeconds >
            block.timestamp
        ) {
            revert StillInCooldown();
        }
        // Check caller is owner of shipToUpgradeEntity and shipToBurnEntity
        ShipNFT shipNft = ShipNFT(_gameRegistry.getSystem(SHIP_NFT_ID));
        (, uint256 shipToUpgradeTokenId) = EntityLibrary.entityToToken(
            input.shipToUpgradeEntity
        );
        (, uint256 shipToBurnTokenId) = EntityLibrary.entityToToken(
            input.shipToBurnEntity
        );
        if (
            shipNft.ownerOf(shipToUpgradeTokenId) != caller ||
            shipNft.ownerOf(shipToBurnTokenId) != caller
        ) {
            revert NotShipOwner();
        }
        // Check no skin attached to shipToBurnEntity
        SkinContainerComponentLayout
            memory skinContainerLayout = SkinContainerComponent(
                _gameRegistry.getComponent(SKIN_CONTAINER_COMPONENT_ID)
            ).getLayoutValue(input.shipToBurnEntity);

        // Check if SHIP_SKIN_GUID is set and revert if true
        for (uint256 i = 0; i < skinContainerLayout.slotEntities.length; i++) {
            if (skinContainerLayout.slotEntities[i] == SHIP_SKIN_GUID) {
                revert SkinEquipped();
            }
        }
        ShipPlanComponentLayout memory shipPlanLayout = ShipPlanComponent(
            _gameRegistry.getComponent(SHIP_PLAN_COMPONENT_ID)
        ).getLayoutValue(input.shipPlanEntity);
        if (shipPlanLayout.costLootSetEntity == 0) {
            revert InvalidShipPlan();
        }
        // Check that shipPlan recipe being used does not exceed current ShipWright capabilities
        if (shipWrightLayout.mergeMaxLevel < shipPlanLayout.levelGranted) {
            revert InvalidShipPlan();
        }
        // Check both ships match the level requirements of the shipPlan being used
        LevelComponent levelComponent = LevelComponent(
            _gameRegistry.getComponent(LEVEL_COMPONENT_ID)
        );
        if (
            shipPlanLayout.requiredShipToUpgradeLevel !=
            levelComponent.getValue(input.shipToUpgradeEntity) ||
            shipPlanLayout.requiredShipToBurnLevel !=
            levelComponent.getValue(input.shipToBurnEntity)
        ) {
            revert InvalidShipLevel();
        }
        // Update level of shipToUpgradeEntity
        levelComponent.setValue(
            input.shipToUpgradeEntity,
            shipPlanLayout.levelGranted
        );
        // Check that both ships are of the same ship-type and are mergeable
        _checkMergeable(
            address(shipNft),
            shipToBurnTokenId,
            shipToUpgradeTokenId
        );
        // Handle fee burning and revenue share
        _handleFeeBurning(
            shipWrightOwner,
            caller,
            shipPlanLayout.costLootSetEntity,
            shipPlanLayout.ownerRevenuePercentage
        );
        // Burn shipToBurnEntity
        shipNft.burn(shipToBurnTokenId);
        // reset merging-cooldown
        ShipWrightCooldownComponent shipWrightCooldownComponent = ShipWrightCooldownComponent(
                _gameRegistry.getComponent(SHIP_WRIGHT_COOLDOWN_COMPONENT_ID)
            );
        ShipWrightCooldownComponentLayout
            memory shipWrightCooldownLayout = shipWrightCooldownComponent
                .getLayoutValue(input.instanceEntity);
        shipWrightCooldownLayout.mergeTimestamp = uint32(block.timestamp);
        shipWrightCooldownComponent.setLayoutValue(
            input.instanceEntity,
            shipWrightCooldownLayout
        );
    }

    /**
     * @dev Set ShipWright as public or private
     * @param instanceEntity Unique guid of the ShipWright on the island
     * @param status Value of public or private or guild
     */
    function setShipWrightPublic(
        uint256 instanceEntity,
        uint256 status
    ) external override whenNotPaused nonReentrant {
        if (status != 0 && status != 1) {
            revert NotValidStatus();
        }
        // Check that instanceEntity exists on an island, is a ShipWright, and caller is owner of the ShipWright
        uint256 islandEntity = SceneObjectParentComponent(
            _gameRegistry.getComponent(SCENE_OBJECT_PARENT_COMPONENT_ID)
        ).getValue(instanceEntity);

        address shipWrightOwner = EntityLibrary.entityToAddress(
            OwnerComponent(_gameRegistry.getComponent(OWNER_COMPONENT_ID))
                .getValue(islandEntity)
        );
        uint256 itemEntity = _getObjectEntity(instanceEntity);
        // Check that instanceEntity is a ShipWright
        ShipWrightComponentLayout memory shipWrightLayout = ShipWrightComponent(
            _gameRegistry.getComponent(SHIP_WRIGHT_COMPONENT_ID)
        ).getLayoutValue(itemEntity);
        if (shipWrightLayout.repairCooldownSeconds == 0) {
            revert NotValidShipWright(itemEntity);
        }
        if (_getPlayerAccount(_msgSender()) != shipWrightOwner) {
            revert NotValidShipWright(instanceEntity);
        }
        PublicUseComponent(_gameRegistry.getComponent(PUBLIC_USE_COMPONENT_ID))
            .setValue(instanceEntity, status);
    }

    /**
     * @dev ShipWright upgrading functionality of ShipWright
     * @param instanceEntity Unique guid of the ShipWright on the island
     */
    function upgradeShipWright(
        uint256 instanceEntity
    ) external override whenNotPaused nonReentrant {
        // Check that instanceEntity exists on an island, is a ShipWright, and caller is owner of the ShipWright
        uint256 islandEntity = SceneObjectParentComponent(
            _gameRegistry.getComponent(SCENE_OBJECT_PARENT_COMPONENT_ID)
        ).getValue(instanceEntity);

        address shipWrightOwner = EntityLibrary.entityToAddress(
            OwnerComponent(_gameRegistry.getComponent(OWNER_COMPONENT_ID))
                .getValue(islandEntity)
        );
        if (_getPlayerAccount(_msgSender()) != shipWrightOwner) {
            revert NotValidShipWright(instanceEntity);
        }
        uint256 itemEntity = _getObjectEntity(instanceEntity);
        // Check that instanceEntity is a ShipWright
        ShipWrightComponentLayout memory shipWrightLayout = ShipWrightComponent(
            _gameRegistry.getComponent(SHIP_WRIGHT_COMPONENT_ID)
        ).getLayoutValue(itemEntity);
        if (shipWrightLayout.repairCooldownSeconds == 0) {
            revert NotValidShipWright(itemEntity);
        }
        UpgradeableItemComponentLayout
            memory upgradeableItemLayout = UpgradeableItemComponent(
                _gameRegistry.getComponent(UPGRADEABLE_ITEM_COMPONENT_ID)
            ).getLayoutValue(itemEntity);
        // Check if max version of ShipWright has been reached
        if (upgradeableItemLayout.nextEntity == 0) {
            revert NotValidShipWright(itemEntity);
        }
        // Burn payment fee for upgrade
        LootArrayComponentLibrary.burnLootArray(
            _gameRegistry.getComponent(LOOT_ARRAY_COMPONENT_ID),
            shipWrightOwner,
            upgradeableItemLayout.lootEntity
        );
        // Replace the current ShipWright on the users island with the next upgraded version
        SceneObjectGameItemComponent(
            _gameRegistry.getComponent(SCENE_OBJECT_GAME_ITEM_COMPONENT_ID)
        ).setValue(instanceEntity, upgradeableItemLayout.nextEntity);
    }

    /**
     * This initializes the cooldown for a generator family in a scene. Called
     * on every scene object addition. Exits early if the scene object is not a
     * generator.
     *
     * @param instanceEntity The entity of the scene object instance
     * @param account The account to that owns the island
     * @param islandEntity The entity of the island
     */
    function initializeCooldownIfShipwright(
        uint256 instanceEntity,
        address account,
        uint256 islandEntity
    ) external override onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        uint256 objectEntity = _getObjectEntity(instanceEntity);
        // Get ShipWright def from game item
        ShipWrightComponent shipWrightComponent = ShipWrightComponent(
            _gameRegistry.getComponent(SHIP_WRIGHT_COMPONENT_ID)
        );
        if (
            shipWrightComponent
                .getLayoutValue(objectEntity)
                .repairCooldownSeconds == 0
        ) {
            // No need to manage cooldown if there's no ShipWright definition
            return;
        }
        // Start cooldowns for ship merging, repair, and swap
        ShipWrightCooldownComponent(
            _gameRegistry.getComponent(SHIP_WRIGHT_COOLDOWN_COMPONENT_ID)
        ).setValue(
                instanceEntity,
                uint32(block.timestamp),
                uint32(block.timestamp),
                uint32(block.timestamp)
            );
        // Track ShipWright on island
        ShipWrightPlacedComponent(
            _gameRegistry.getComponent(SHIPWRIGHT_PLACED_COMPONENT_ID)
        ).setValue(instanceEntity, account, islandEntity);
    }

    /* INTERNAL */

    /**
     * @dev Get GameItem from SceneObject.
     */
    function _getObjectEntity(
        uint256 instanceEntity
    ) internal view returns (uint256) {
        return
            SceneObjectGameItemComponent(
                _gameRegistry.getComponent(SCENE_OBJECT_GAME_ITEM_COMPONENT_ID)
            ).getValue(instanceEntity);
    }

    /**
     * @dev Check if ShipWright is public or private and if caller is allowed to call.
     * @param instanceEntity Unique guid of the ShipWright on the island
     * @param caller Address of the caller
     */
    function _checkValidShipWrightCall(
        uint256 instanceEntity,
        address caller
    ) internal view returns (address) {
        uint256 islandEntity = SceneObjectParentComponent(
            _gameRegistry.getComponent(SCENE_OBJECT_PARENT_COMPONENT_ID)
        ).getValue(instanceEntity);

        address shipWrightOwner = EntityLibrary.entityToAddress(
            OwnerComponent(_gameRegistry.getComponent(OWNER_COMPONENT_ID))
                .getValue(islandEntity)
        );
        // Determine if ShipWright is set as public or private
        if (
            PublicUseComponent(
                _gameRegistry.getComponent(PUBLIC_USE_COMPONENT_ID)
            ).getValue(instanceEntity) == 0
        ) {
            // Only owner may call if private
            if (shipWrightOwner != caller) {
                revert ShipWrightPrivate();
            }
        }
        return shipWrightOwner;
    }

    /**
     * @dev Handle burning the payment fee and revenue share
     * @param shipWrightOwner Address of the owner of the ShipWright
     * @param caller Address of the caller
     * @param costLootSetEntity Entity of the LootSet to burn
     * @param revenuePercent Percentage of the payment fee to pay to the owner of the ShipWright
     */
    function _handleFeeBurning(
        address shipWrightOwner,
        address caller,
        uint256 costLootSetEntity,
        uint256 revenuePercent
    ) internal {
        // Burn payment fee for upgrading aka merging ship
        LootArrayComponentLibrary.burnLootArray(
            _gameRegistry.getComponent(LOOT_ARRAY_COMPONENT_ID),
            caller,
            costLootSetEntity
        );
        // Pay owner of shipwright the revenue tax
        LootArrayComponentLayout memory lootArrayLayout = LootArrayComponent(
            _gameRegistry.getComponent(LOOT_ARRAY_COMPONENT_ID)
        ).getLayoutValue(costLootSetEntity);
        for (uint i = 0; i < lootArrayLayout.lootType.length; i++) {
            // apply revenue tax to owner of ShipWright,
            if (
                lootArrayLayout.lootType[i] ==
                uint32(ILootSystem.LootType.ERC20)
            ) {
                IGameCurrency(lootArrayLayout.tokenContract[i]).mint(
                    shipWrightOwner,
                    (lootArrayLayout.amount[i] * revenuePercent) / 100
                );
                break;
            }
        }
    }

    /**
     * @dev Check if both ships are mergeable
     * @param shipNFT Address of the ShipNFT contract
     * @param shipToBurnTokenId TokenId of the ship to burn
     * @param shipToUpgradeTokenId TokenId of the ship to upgrade
     */
    function _checkMergeable(
        address shipNFT,
        uint256 shipToBurnTokenId,
        uint256 shipToUpgradeTokenId
    ) internal view {
        MixinComponent mixinComponent = MixinComponent(
            _gameRegistry.getComponent(MIXIN_COMPONENT_ID)
        );
        ShipTypeComponent shipTypeComponent = ShipTypeComponent(
            _gameRegistry.getComponent(SHIP_TYPE_COMPONENT_ID)
        );
        uint256 shipToBurnTemplateId = mixinComponent
            .getLayoutValue(
                EntityLibrary.tokenToEntity(shipNFT, shipToBurnTokenId)
            )
            .value[0];

        uint256 shipToUpgradeTemplateId = mixinComponent
            .getLayoutValue(
                EntityLibrary.tokenToEntity(shipNFT, shipToUpgradeTokenId)
            )
            .value[0];
        // Ensure that ship-to-burn is allowed to be burned and ensure both ships are of the same base type
        (, uint256 shipToBurnBaseType) = shipTypeComponent.getValue(
            shipToBurnTemplateId
        );
        (, uint256 shipToUpgradeBaseType) = shipTypeComponent.getValue(
            shipToUpgradeTemplateId
        );
        if (
            ShipTypeMergeableComponent(
                _gameRegistry.getComponent(SHIP_TYPE_MERGEABLE_COMPONENT_ID)
            ).getValue(shipToBurnTemplateId) == false
        ) {
            revert InvalidShipTypes();
        }
        if (shipToBurnBaseType != shipToUpgradeBaseType) {
            revert InvalidShipTypes();
        }
    }
}
