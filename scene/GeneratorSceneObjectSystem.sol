// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {IS_PLACEABLE_TRAIT_ID, GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {OwnerSystem} from "../core/OwnerSystem.sol";
import {ITraitsProvider} from "../interfaces/ITraitsProvider.sol";
import {ILootSystem} from "../loot/ILootSystem.sol";
import {SceneObjectGameItem, SceneObjectGameItemComponent, ID as SCENE_OBJECT_GAME_ITEM_COMPONENT_ID} from "../generated/components/SceneObjectGameItemComponent.sol";
import {Layout as GeneratorCooldownTimestamp, GeneratorCooldownTimestampComponent, ID as GENERATOR_COOLDOWN_TIMESTAMP_COMPONENT_ID} from "../generated/components/GeneratorCooldownTimestampComponent.sol";
import {Layout as GeneratorObjectDefinition, GeneratorObjectDefinitionComponent, ID as GENERATOR_SCENE_OBJECT_DEFINITION_COMPONENT_ID} from "../generated/components/GeneratorObjectDefinitionComponent.sol";
import {LootSetComponent, ID as LOOT_SET_COMPONENT_ID} from "../generated/components/LootSetComponent.sol";
import {SceneObjectParentComponent, ID as SCENE_OBJECT_PARENT_COMPONENT_ID} from "../generated/components/SceneObjectParentComponent.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.generatorsceneobjectsystem")
);

/**
 * @title Contract for generator SceneObjects
 */
contract GeneratorSceneObjectSystem is OwnerSystem {
    /** ERRORS **/

    /// @notice The cooldown for the scene + generator family combination has not finished yet.
    error GeneratorNotRecharged(uint256 sceneEntity, uint256 generatorFamily);

    /// @notice Error when a scene object is not a valid generator
    error InvalidGenerator(uint256 instanceEntity);

    error InvalidIslandOwner();

    error InvalidGeneratorOwner();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * This initializes the cooldown for a generator family in a scene. Called
     * on every scene object addition. Exits early if the scene object is not a
     * generator.
     *
     * @param instanceEntity The entity of the scene object instance
     */
    function initializeCooldownIfGenerator(
        uint256 instanceEntity
    ) external onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        uint256 objectEntity = _getObjectEntity(instanceEntity);
        // Get generator spec from game item
        GeneratorObjectDefinitionComponent definitionComponent = GeneratorObjectDefinitionComponent(
                _gameRegistry.getComponent(
                    GENERATOR_SCENE_OBJECT_DEFINITION_COMPONENT_ID
                )
            );

        if (!definitionComponent.has(objectEntity)) {
            // No need to manage cooldown if there's no generator definition
            return;
        }
        // Start cooldown for scene object instance
        _setCooldown(instanceEntity, block.timestamp);
    }

    /**
     * Collect generated loot from a generator.
     *
     * @param account The account to receive the loot
     * @param sceneEntity The entity of the scene
     * @param instanceEntity The entity of the scene object instance being harvested
     */
    function collectGeneratedLoot(
        address account,
        uint256 sceneEntity,
        uint256 instanceEntity
    ) external whenNotPaused nonReentrant onlyEntityOwner(sceneEntity) {
        uint256 objectEntity = _getObjectEntity(instanceEntity);
        // Enforce account calling receives loot
        address caller = _getPlayerAccount(_msgSender());
        if (caller != account) {
            revert InvalidIslandOwner();
        }
        // Enforce instanceEntity belongs to sceneEntity
        uint256 parentEntity = SceneObjectParentComponent(
            _gameRegistry.getComponent(SCENE_OBJECT_PARENT_COMPONENT_ID)
        ).getValue(instanceEntity).parentEntity;
        if (parentEntity != sceneEntity) {
            revert InvalidGeneratorOwner();
        }
        GeneratorObjectDefinition
            memory definition = _getGeneratorObjectDefinition(objectEntity);

        // Revert if instanceEntity does not belong to a generator.
        if (definition.generatorFamily == 0) {
            revert InvalidGenerator(instanceEntity);
        }

        // Get generator family cooldown for account, and revert if not ready.
        uint256 sceneCooldownEntity = uint256(
            keccak256(abi.encode(sceneEntity, definition.generatorFamily))
        );
        uint256 cooldown = _getCooldown(sceneCooldownEntity);
        if (cooldown + definition.durationSecs > block.timestamp) {
            revert GeneratorNotRecharged(
                sceneEntity,
                definition.generatorFamily
            );
        }

        // Get cooldown for instanceEntity, and revert if not ready.
        cooldown = _getCooldown(instanceEntity);
        if (cooldown + definition.durationSecs > block.timestamp) {
            revert GeneratorNotRecharged(
                instanceEntity,
                definition.generatorFamily
            );
        }

        // Set cooldown to prevent future collections.
        _setCooldown(sceneCooldownEntity, block.timestamp);
        // Set cooldown to prevent generator future collections.
        _setCooldown(instanceEntity, block.timestamp);

        ILootSystem lootSystem = _lootSystem();
        ILootSystem.Loot[] memory loot = _convertLootSet(
            definition.lootSetEntity
        );
        lootSystem.grantLoot(account, loot);
    }

    /* INTERNAL */

    /**
     * Get GameItem from SceneObject.
     */
    function _getObjectEntity(
        uint256 instanceEntity
    ) internal view returns (uint256) {
        return
            SceneObjectGameItemComponent(
                _gameRegistry.getComponent(SCENE_OBJECT_GAME_ITEM_COMPONENT_ID)
            ).getValue(instanceEntity).itemEntity;
    }

    /**
     * Get GeneratorObjectDefinition from a GameItem.
     */
    function _getGeneratorObjectDefinition(
        uint256 objectEntity
    ) internal view returns (GeneratorObjectDefinition memory) {
        return
            GeneratorObjectDefinitionComponent(
                _gameRegistry.getComponent(
                    GENERATOR_SCENE_OBJECT_DEFINITION_COMPONENT_ID
                )
            ).getLayoutValue(objectEntity);
    }

    /**
     * Get the cooldown timestamp for an entity.
     */
    function _getCooldown(uint256 entity) internal view returns (uint256) {
        return
            GeneratorCooldownTimestampComponent(
                _gameRegistry.getComponent(
                    GENERATOR_COOLDOWN_TIMESTAMP_COMPONENT_ID
                )
            ).getLayoutValue(entity).timestamp;
    }

    /**
     * Set the cooldown timestamp for an entity.
     */
    function _setCooldown(uint256 entity, uint256 timestamp) internal {
        return
            GeneratorCooldownTimestampComponent(
                _gameRegistry.getComponent(
                    GENERATOR_COOLDOWN_TIMESTAMP_COMPONENT_ID
                )
            ).setLayoutValue(
                    entity,
                    GeneratorCooldownTimestamp({timestamp: timestamp})
                );
    }

    /**
     * Converts a LootSetComponent to a ILootSystem.Loot array
     *
     * @param lootSetEntity The LootSetComponent GUID
     */
    function _convertLootSet(
        uint256 lootSetEntity
    ) internal view returns (ILootSystem.Loot[] memory) {
        // Get the LootSet component values uisng the lootSetId
        (
            uint32[] memory lootType,
            address[] memory tokenContract,
            uint256[] memory lootId,
            uint256[] memory amount
        ) = LootSetComponent(_gameRegistry.getComponent(LOOT_SET_COMPONENT_ID))
                .getValue(lootSetEntity);
        // Convert them to an ILootSystem.Loot array
        ILootSystem.Loot[] memory loot = new ILootSystem.Loot[](
            lootType.length
        );
        for (uint256 i = 0; i < lootType.length; i++) {
            loot[i] = ILootSystem.Loot(
                ILootSystem.LootType(lootType[i]),
                tokenContract[i],
                lootId[i],
                amount[i]
            );
        }
        return loot;
    }
}
