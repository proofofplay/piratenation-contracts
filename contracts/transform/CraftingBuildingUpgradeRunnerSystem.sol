// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import {EntityLibrary} from "../core/EntityLibrary.sol";
import {LootArrayComponentLibrary} from "../loot/LootArrayComponentLibrary.sol";

import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";

import {ITransformRunnerSystem, TransformParams} from "./ITransformRunnerSystem.sol";
import {BaseTransformRunnerSystem, TransformInstanceComponentLayout} from "./BaseTransformRunnerSystem.sol";
import {SceneObjectParentComponent, ID as SCENE_OBJECT_PARENT_COMPONENT_ID} from "../generated/components/SceneObjectParentComponent.sol";
import {SceneObjectGameItemComponent, ID as SCENE_OBJECT_GAME_ITEM_COMPONENT_ID} from "../generated/components/SceneObjectGameItemComponent.sol";
import {OwnerComponent, ID as OWNER_COMPONENT_ID} from "../generated/components/OwnerComponent.sol";
import {CraftingBuildingUpgradeRunnerConfigComponent, Layout as CraftingBuildingUpgradeRunnerConfigComponentLayout, ID as CRAFTING_BUILDING_UPGRADE_RUNNER_CONFIG_COMPONENT_ID} from "../generated/components/CraftingBuildingUpgradeRunnerConfigComponent.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.craftingbuildingupgraderunnersystem")
);

contract CraftingBuildingUpgradeRunnerSystem is BaseTransformRunnerSystem {
    /** ERRORS */

    /// @notice Cannot execute multiple transforms
    error CannotExecuteMultipleTransform();

    /// @notice Invalid Instance Entity
    error InvalidInstanceEntity();

    /// @notice Not building owner
    error NotBuildingOwner();

    /// @notice Invalid upgrade request
    error InvalidUpgradeRequest();

    /// @notice Building requirement not met
    error InvalidBuildingRequirement();

    /** PUBLIC */

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function startTransform(
        TransformInstanceComponentLayout memory transformInstance,
        uint256,
        TransformParams calldata params
    )
        external
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (bool needsVrf, bool skipTransformInstance)
    {
        uint256 instanceEntity = abi.decode(params.data, (uint256));
        if (instanceEntity == 0) {
            revert InvalidInstanceEntity();
        }
        // Check that instanceEntity exists on an island and caller is owner
        uint256 islandEntity = SceneObjectParentComponent(
            _gameRegistry.getComponent(SCENE_OBJECT_PARENT_COMPONENT_ID)
        ).getValue(instanceEntity);
        if (islandEntity == 0) {
            revert InvalidInstanceEntity();
        }
        address buildingOwner = EntityLibrary.entityToAddress(
            OwnerComponent(_gameRegistry.getComponent(OWNER_COMPONENT_ID))
                .getValue(islandEntity)
        );
        if (transformInstance.account != buildingOwner) {
            revert NotBuildingOwner();
        }
        CraftingBuildingUpgradeRunnerConfigComponentLayout
            memory config = CraftingBuildingUpgradeRunnerConfigComponent(
                _gameRegistry.getComponent(
                    CRAFTING_BUILDING_UPGRADE_RUNNER_CONFIG_COMPONENT_ID
                )
            ).getLayoutValue(transformInstance.transformEntity);
        if (config.nextLevelEntity == 0) {
            revert InvalidUpgradeRequest();
        }
        uint256 itemEntity = _getObjectEntity(instanceEntity);
        if (itemEntity != config.currentLevelEntity) {
            revert InvalidBuildingRequirement();
        }
        // Replace the current building on the users island with the next upgraded version
        SceneObjectGameItemComponent(
            _gameRegistry.getComponent(SCENE_OBJECT_GAME_ITEM_COMPONENT_ID)
        ).setValue(instanceEntity, config.nextLevelEntity);

        return (needsVrf, skipTransformInstance);
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function completeTransform(
        TransformInstanceComponentLayout memory transformInstance,
        uint256,
        uint256 randomWord
    )
        external
        view
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (uint16 numSuccess, uint256 nextRandomWord)
    {
        numSuccess = transformInstance.count;
        return (numSuccess, randomWord);
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function isTransformCompleteable(
        TransformInstanceComponentLayout memory transformInstance
    ) external pure override returns (bool) {
        return _isCompleteable(transformInstance);
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function isTransformAvailable(
        address,
        TransformParams calldata params
    ) external pure override returns (bool) {
        // Prevent multiple transforms
        if (params.count != 1) {
            revert CannotExecuteMultipleTransform();
        }
        return true;
    }

    /** INTERNAL */

    /**
     * Validate completeTransform call
     */
    function _isCompleteable(
        TransformInstanceComponentLayout memory
    ) internal pure returns (bool) {
        return true;
    }

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
}
