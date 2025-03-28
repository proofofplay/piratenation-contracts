// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

import {GAME_ITEMS_CONTRACT_ROLE, GAME_NFT_CONTRACT_ROLE} from "../Constants.sol";
import {ICooldownSystem, ID as COOLDOWN_SYSTEM_ID} from "../cooldown/ICooldownSystem.sol";
import {Layout as TransformP3R1} from "../generated/components/TransformP3R1Component.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {OwnerSystem} from "../core/OwnerSystem.sol";
import {Uint256Component, ID as UINT256_COMPONENT_ID} from "../generated/components/Uint256Component.sol";
import {IGameItems} from "../tokens/gameitems/IGameItems.sol";
import {SceneObjectParams, ISceneSystem} from "./ISceneSystem.sol";
import {PlaceableSceneObjectSystem, ID as PLACEABLE_SCENE_OBJECT_SYSTEM_ID} from "./PlaceableSceneObjectSystem.sol";
import {SceneObjectParentComponent, ID as SCENE_OBJECT_PARENT_COMPONENT_ID} from "../generated/components/SceneObjectParentComponent.sol";
import {SceneObjectGameItemComponent, ID as SCENE_OBJECT_GAME_ITEM_COMPONENT_ID} from "../generated/components/SceneObjectGameItemComponent.sol";
import {GeneratorSceneObjectSystem, ID as GENERATOR_SCENE_OBJECT_SYSTEM_ID} from "./GeneratorSceneObjectSystem.sol";
import {IShipWrightSystem, ID as SHIPWRIGHT_SYSTEM_ID} from "./IShipWrightSystem.sol";
import {ShipWrightPlacedComponent, ID as SHIPWRIGHT_PLACED_COMPONENT_ID} from "../generated/components/ShipWrightPlacedComponent.sol";
import {ShipWrightComponent, ID as SHIPWRIGHT_COMPONENT_ID} from "../generated/components/ShipWrightComponent.sol";
import {PendingIslandTransformListComponent, Layout as PendingIslandTransformListComponentLayout, ID as PENDING_ISLAND_TRANSFORM_LIST_COMPONENT_ID} from "../generated/components/PendingIslandTransformListComponent.sol";
import {CraftingSlotsGrantedComponent, ID as CRAFTING_SLOTS_GRANTED_COMPONENT_ID} from "../generated/components/CraftingSlotsGrantedComponent.sol";
import {CounterComponent, Layout as CounterComponentLayout, ID as COUNTER_COMPONENT_ID} from "../generated/components/CounterComponent.sol";
import {EntityBaseComponent, ID as ENTITY_BASE_COMPONENT_ID} from "../generated/components/EntityBaseComponent.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.scenesystem"));

// Game Global with minimum time.
uint256 constant SCENE_PLACEMENT_COOLDOWN_SECS = uint256(
    keccak256("game.piratenation.global.scene.placement_cooldown_secs")
);

// Key for Cooldown System per account.
uint256 constant SCENE_PLACEMENT_COOLDOWN_ID = uint256(
    keccak256("scene_system.placement_cooldown_id")
);

/**
 * @title Contract that manages entities placed within a scene
 */
abstract contract SceneSystem is OwnerSystem, ISceneSystem {
    /** ERRORS **/

    /// @notice Invalid item cannot be added to the scene
    error InvalidItem(uint256 objectEntity);

    /// @notice Invalid item instance cannot be added to the scene
    error InvalidItemInstance(uint256 instanceEntity);

    /// @notice Account is still in cooldown
    error AccountStillInCooldown();

    /// @notice Pending crafting building transforms exist
    error PendingCraftingTransformsExist();

    /// @notice Crafting building already exists on island
    error CraftingBuildingAlreadyExists();

    /**
     * @inheritdoc ISceneSystem
     */
    function addOrUpdateSceneObjects(
        uint256 sceneEntity,
        SceneObjectParams[] calldata addedObjectParams
    ) external whenNotPaused nonReentrant onlyEntityOwner(sceneEntity) {
        address account = _getPlayerAccount(_msgSender());
        _validateCooldown(account);
        GeneratorSceneObjectSystem generatorSceneObjectSystem = GeneratorSceneObjectSystem(
                _getSystem(GENERATOR_SCENE_OBJECT_SYSTEM_ID)
            );
        IShipWrightSystem shipWrightSystem = IShipWrightSystem(
            _getSystem(SHIPWRIGHT_SYSTEM_ID)
        );

        // Iterate through each scene object and place it in the scene
        for (uint256 i = 0; i < addedObjectParams.length; i++) {
            _addOrUpdateSceneObject(
                account,
                sceneEntity,
                addedObjectParams[i],
                generatorSceneObjectSystem,
                shipWrightSystem
            );
        }
    }

    /**
     * @inheritdoc ISceneSystem
     */
    function removeSceneObjects(
        uint256 sceneEntity,
        uint256[] calldata removedInstanceEntities
    ) external whenNotPaused nonReentrant onlyEntityOwner(sceneEntity) {
        address account = _getPlayerAccount(_msgSender());
        _validateCooldown(account);

        // Iterate through each placed object instance and remove it from scene
        for (uint256 i = 0; i < removedInstanceEntities.length; i++) {
            _removeSceneObject(
                account,
                sceneEntity,
                removedInstanceEntities[i]
            );
        }
    }

    /**
     * @inheritdoc ISceneSystem
     */
    function updateScene(
        uint256 sceneEntity,
        uint256[] calldata removedInstanceEntities,
        SceneObjectParams[] calldata addedObjectParams
    ) external whenNotPaused nonReentrant onlyEntityOwner(sceneEntity) {
        address account = _getPlayerAccount(_msgSender());
        _validateCooldown(account);
        GeneratorSceneObjectSystem generatorSceneObjectSystem = GeneratorSceneObjectSystem(
                _getSystem(GENERATOR_SCENE_OBJECT_SYSTEM_ID)
            );
        IShipWrightSystem shipWrightSystem = IShipWrightSystem(
            _getSystem(SHIPWRIGHT_SYSTEM_ID)
        );

        // Iterate through each placed object instance and remove it from scene
        for (uint256 i = 0; i < removedInstanceEntities.length; i++) {
            _removeSceneObject(
                account,
                sceneEntity,
                removedInstanceEntities[i]
            );
        }

        // Iterate through each scene object and place it in the scene
        for (uint256 i = 0; i < addedObjectParams.length; i++) {
            _addOrUpdateSceneObject(
                account,
                sceneEntity,
                addedObjectParams[i],
                generatorSceneObjectSystem,
                shipWrightSystem
            );
        }
    }

    /** INTERNAL **/

    /**
     * @dev Places a scene object at the given coordinates
     *
     * @param account      Account of the player
     * @param sceneEntity  Entity of the scene
     * @param objectParams Parameters for scene object to add
     */
    function _addOrUpdateSceneObject(
        address account,
        uint256 sceneEntity,
        SceneObjectParams calldata objectParams,
        GeneratorSceneObjectSystem generatorSceneObjectSystem,
        IShipWrightSystem shipWrightSystem
    ) internal {
        // Check parent contract validations
        if (!_canAddOrUpdateSceneObject(sceneEntity, objectParams)) {
            revert InvalidItem(objectParams.objectEntity);
        }

        // If the item has already been placed, then modify the existing instance
        if (objectParams.instanceEntity != 0) {
            PlaceableSceneObjectSystem(
                _getSystem(PLACEABLE_SCENE_OBJECT_SYSTEM_ID)
            ).update(
                    objectParams.instanceEntity,
                    TransformP3R1({
                        x: objectParams.x,
                        y: objectParams.y,
                        z: objectParams.z,
                        rotation: objectParams.rotation
                    })
                );
        } else {
            // Burn the item from inventory
            _burnSceneObject(account, objectParams.objectEntity);

            // Add item to scene
            uint256 instanceEntity = PlaceableSceneObjectSystem(
                _getSystem(PLACEABLE_SCENE_OBJECT_SYSTEM_ID)
            ).create(
                    objectParams.objectEntity,
                    TransformP3R1({
                        x: objectParams.x,
                        y: objectParams.y,
                        z: objectParams.z,
                        rotation: objectParams.rotation
                    })
                );

            // Set owner of our PlaceableSceneObject to be the scene entity.
            SceneObjectParentComponent(
                _gameRegistry.getComponent(SCENE_OBJECT_PARENT_COMPONENT_ID)
            ).setValue(instanceEntity, sceneEntity);

            // Check if the object is a generator and initialize cooldown if so
            generatorSceneObjectSystem.initializeCooldownIfGenerator(
                instanceEntity
            );
            // Check if the object is a shipwright and init cooldown
            shipWrightSystem.initializeCooldownIfShipwright(
                instanceEntity,
                account,
                sceneEntity
            );
            // Check if object is a crafting building and enforce only one type per island
            if (
                CraftingSlotsGrantedComponent(
                    _gameRegistry.getComponent(
                        CRAFTING_SLOTS_GRANTED_COMPONENT_ID
                    )
                ).has(objectParams.objectEntity)
            ) {
                CounterComponent counterComponent = CounterComponent(
                    _gameRegistry.getComponent(COUNTER_COMPONENT_ID)
                );
                // Pack the account and the EntityBase into a unique ID
                uint256 walletBuildingEntityId = uint256(
                    keccak256(
                        abi.encodePacked(
                            account,
                            EntityBaseComponent(
                                _gameRegistry.getComponent(
                                    ENTITY_BASE_COMPONENT_ID
                                )
                            ).getValue(objectParams.objectEntity)
                        )
                    )
                );
                if (counterComponent.has(walletBuildingEntityId)) {
                    revert CraftingBuildingAlreadyExists();
                }
                counterComponent.setValue(walletBuildingEntityId, 1);
            }
        }
    }

    /**
     * @dev Removes a scene object instance from a scene
     *
     * @param account        Account of the player
     * @param sceneEntity    Entity of the scene
     * @param instanceEntity Parameters for scene object to add
     */
    function _removeSceneObject(
        address account,
        uint256 sceneEntity,
        uint256 instanceEntity
    ) internal {
        // Check parent contract validations
        if (!_canRemoveSceneObject(sceneEntity, instanceEntity)) {
            revert InvalidItemInstance(instanceEntity);
        }

        // Get the object entity from the instance
        uint256 gameItemEntity = SceneObjectGameItemComponent(
            _gameRegistry.getComponent(SCENE_OBJECT_GAME_ITEM_COMPONENT_ID)
        ).getValue(instanceEntity);

        // Check if the object is a shipwright and wipe its ShipWrightPlacedComponent
        if (
            ShipWrightComponent(
                _gameRegistry.getComponent(SHIPWRIGHT_COMPONENT_ID)
            ).getLayoutValue(gameItemEntity).repairCooldownSeconds != 0
        ) {
            ShipWrightPlacedComponent(
                _gameRegistry.getComponent(SHIPWRIGHT_PLACED_COMPONENT_ID)
            ).remove(instanceEntity);
        }
        // Enforce crafting building cannot be removed if it has pending transforms
        if (
            PendingIslandTransformListComponent(
                _gameRegistry.getComponent(
                    PENDING_ISLAND_TRANSFORM_LIST_COMPONENT_ID
                )
            ).getLayoutValue(instanceEntity).value.length > 0
        ) {
            revert PendingCraftingTransformsExist();
        }

        // Check if object is a crafting building and remove counter
        if (
            CraftingSlotsGrantedComponent(
                _gameRegistry.getComponent(CRAFTING_SLOTS_GRANTED_COMPONENT_ID)
            ).has(gameItemEntity)
        ) {
            CounterComponent(_gameRegistry.getComponent(COUNTER_COMPONENT_ID))
                .remove(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                account,
                                EntityBaseComponent(
                                    _gameRegistry.getComponent(
                                        ENTITY_BASE_COMPONENT_ID
                                    )
                                ).getValue(gameItemEntity)
                            )
                        )
                    )
                );
        }

        // Remove the instance from the scene
        PlaceableSceneObjectSystem(_getSystem(PLACEABLE_SCENE_OBJECT_SYSTEM_ID))
            .remove(instanceEntity);

        // Mint the item back to the user
        _mintSceneObject(account, gameItemEntity);

        // Remove owner from PlaceableSceneObject
        SceneObjectParentComponent(
            _gameRegistry.getComponent(SCENE_OBJECT_PARENT_COMPONENT_ID)
        ).remove(instanceEntity);
    }

    /**
     * Function to override with custom validation logic
     *
     * @param sceneEntity  A packed tokenId and address for a scene entity
     * @param objectParams Parameters for scene object to add
     */
    function _canAddOrUpdateSceneObject(
        uint256 sceneEntity,
        SceneObjectParams calldata objectParams
    ) internal virtual returns (bool);

    /**
     * Function to override with custom validation logic
     *
     * @param sceneEntity    A packed tokenId and address for a scene entity
     * @param instanceEntity Entity of the placed scene object to remove
     */
    function _canRemoveSceneObject(
        uint256 sceneEntity,
        uint256 instanceEntity
    ) internal virtual returns (bool);

    /**
     * Mints an ERC1155 or ERC721 scene object
     *
     * @param account      Account of the player
     * @param objectEntity Entity of the scene object to mint
     */
    function _mintSceneObject(address account, uint256 objectEntity) internal {
        (address tokenContract, uint256 tokenId) = EntityLibrary.entityToToken(
            objectEntity
        );

        // Mint the item when removing it from the scene
        if (_hasAccessRole(GAME_ITEMS_CONTRACT_ROLE, tokenContract)) {
            // Handle minting ERC1155
            IGameItems(tokenContract).mint(account, tokenId, 1);
        } else if (_hasAccessRole(GAME_NFT_CONTRACT_ROLE, tokenContract)) {
            // TODO: Is this the right approach for 721s?
            // IGameNFT(tokenContract).mint(account, tokenId);
        } else {
            // Unsupported item
            revert InvalidItem(objectEntity);
        }
    }

    /**
     * Burns an ERC1155 or ERC721 scene object
     *
     * @param account      Account of the player
     * @param objectEntity Entity of the scene object to burn
     */
    function _burnSceneObject(address account, uint256 objectEntity) internal {
        (address tokenContract, uint256 tokenId) = EntityLibrary.entityToToken(
            objectEntity
        );

        if (_hasAccessRole(GAME_ITEMS_CONTRACT_ROLE, tokenContract)) {
            // Handle burning ERC1155; check if parent is owner of item
            if (IERC1155(tokenContract).balanceOf(account, tokenId) == 0) {
                revert InvalidItem(objectEntity);
            }

            // Burn the item when storing it in the scene
            ERC1155Burnable(tokenContract).burn(account, tokenId, 1);
        } else if (_hasAccessRole(GAME_NFT_CONTRACT_ROLE, tokenContract)) {
            // Handle burning ERC721; check if parent is owner of item
            if (IERC721(tokenContract).ownerOf(tokenId) != account) {
                revert InvalidItem(objectEntity);
            }

            // TODO: Is this the right approach for 721s?
            // ERC721(tokenContract).burn(tokenId);
        } else {
            // Unsupported item
            revert InvalidItem(objectEntity);
        }
    }

    /**
     * Checks & updates the cooldown
     *
     * @param account Account of the player
     */
    function _validateCooldown(address account) internal {
        uint32 scenePlacementCooldownLimit = uint32(
            Uint256Component(_gameRegistry.getComponent(UINT256_COMPONENT_ID))
                .getValue(SCENE_PLACEMENT_COOLDOWN_SECS)
        );

        // Apply cooldown on account, revert if still in cooldown
        if (
            ICooldownSystem(_getSystem(COOLDOWN_SYSTEM_ID))
                .updateAndCheckCooldown(
                    EntityLibrary.addressToEntity(account),
                    SCENE_PLACEMENT_COOLDOWN_ID,
                    scenePlacementCooldownLimit
                )
        ) {
            revert AccountStillInCooldown();
        }
    }
}
