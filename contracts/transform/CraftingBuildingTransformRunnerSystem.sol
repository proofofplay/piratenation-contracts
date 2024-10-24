// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import {EntityLibrary} from "../core/EntityLibrary.sol";

import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";

import {ITransformRunnerSystem, TransformParams} from "./ITransformRunnerSystem.sol";
import {BaseTransformRunnerSystem, TransformInstanceComponentLayout} from "./BaseTransformRunnerSystem.sol";

import {PublicUseComponent, ID as PUBLIC_USE_COMPONENT_ID} from "../generated/components/PublicUseComponent.sol";
import {SceneObjectParentComponent, ID as SCENE_OBJECT_PARENT_COMPONENT_ID} from "../generated/components/SceneObjectParentComponent.sol";
import {SceneObjectGameItemComponent, ID as SCENE_OBJECT_GAME_ITEM_COMPONENT_ID} from "../generated/components/SceneObjectGameItemComponent.sol";
import {OwnerComponent, ID as OWNER_COMPONENT_ID} from "../generated/components/OwnerComponent.sol";
import {CraftingSlotsGrantedComponent, ID as CRAFTING_SLOTS_GRANTED_COMPONENT_ID} from "../generated/components/CraftingSlotsGrantedComponent.sol";
import {PendingIslandTransformListComponent, Layout as PendingIslandTransformListComponentLayout, ID as PENDING_ISLAND_TRANSFORM_LIST_COMPONENT_ID} from "../generated/components/PendingIslandTransformListComponent.sol";
import {TransformCraftingBuildingTrackerComponent, ID as TRANSFORM_CRAFTING_BUILDING_TRACKER_COMPONENT_ID} from "../generated/components/TransformCraftingBuildingTrackerComponent.sol";
import {CraftingBuildingTransformConfigComponent, Layout as CraftingBuildingTransformConfigComponentLayout, ID as CRAFTING_BUILDING_TRANSFORM_CONFIG_COMPONENT_ID} from "../generated/components/CraftingBuildingTransformConfigComponent.sol";
import {TransformConfigTimeLockComponent, Layout as TransformConfigTimeLockComponentLayout, ID as TRANSFORM_CONFIG_TIME_LOCK_COMPONENT_ID} from "../generated/components/TransformConfigTimeLockComponent.sol";
import {TransformInstanceComponent, Layout as TransformInstanceComponentLayout, ID as TRANSFORM_INSTANCE_COMPONENT_ID} from "../generated/components/TransformInstanceComponent.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.craftingbuildingtransformrunnersystem")
);

contract CraftingBuildingTransformRunnerSystem is BaseTransformRunnerSystem {
    /** ERRORS */

    /// @notice Error when CraftingBuilding is private
    error CraftingBuildingPrivate();

    /// @notice Invalid Instance Entity
    error InvalidInstanceEntity();

    /// @notice Exceeds Max Queue Slot
    error ExceedsMaxQueueSlot();

    /// @notice Invalid Transform for Building
    error InvalidTransformForBuilding();

    /// @notice Cannot execute multiple transforms
    error CannotExecuteMultipleTransform();

    /// @notice Building not found
    error BuildingNotFound();

    /// @notice ZeroSlotCount
    error ZeroSlotCount();

    /// @notice NotFirstInQueue
    error NotFirstInQueue();

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
        uint256 transformInstanceEntity,
        TransformParams calldata params
    )
        external
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (bool needsVrf, bool skipTransformInstance)
    {
        // Validation checks performed in isTransformAvailable
        uint256 buildingInstanceEntity = abi.decode(params.data, (uint256));

        // Check queue slot count is not exceeded
        PendingIslandTransformListComponent pendingIslandTransformListComponent = PendingIslandTransformListComponent(
                _gameRegistry.getComponent(
                    PENDING_ISLAND_TRANSFORM_LIST_COMPONENT_ID
                )
            );
        PendingIslandTransformListComponentLayout
            memory pendingList = pendingIslandTransformListComponent
                .getLayoutValue(buildingInstanceEntity);
        if (
            pendingList.value.length + params.count >
            getMaxQueueSlotCount(buildingInstanceEntity)
        ) {
            revert ExceedsMaxQueueSlot();
        }
        uint256[] memory newInstances = new uint256[](1);
        newInstances[0] = transformInstanceEntity;
        pendingIslandTransformListComponent.append(
            buildingInstanceEntity,
            PendingIslandTransformListComponentLayout(newInstances)
        );
        // Record the instance entity used for the transform
        TransformCraftingBuildingTrackerComponent(
            _gameRegistry.getComponent(
                TRANSFORM_CRAFTING_BUILDING_TRACKER_COMPONENT_ID
            )
        ).setValue(transformInstanceEntity, buildingInstanceEntity);
        // If no pending transforms, set the start time to now
        if (pendingList.value.length == 0) {
            return (false, false);
        }
        // Handle setting transformInstanceEntity in runner
        skipTransformInstance = true;
        // Get the previous transform instance and check if its still running
        TransformInstanceComponent transformInstanceComponent = TransformInstanceComponent(
                _gameRegistry.getComponent(TRANSFORM_INSTANCE_COMPONENT_ID)
            );
        TransformInstanceComponentLayout
            memory previousTransformInstance = transformInstanceComponent
                .getLayoutValue(
                    pendingList.value[pendingList.value.length - 1]
                );
        TransformConfigTimeLockComponentLayout
            memory config = TransformConfigTimeLockComponent(
                _gameRegistry.getComponent(
                    TRANSFORM_CONFIG_TIME_LOCK_COMPONENT_ID
                )
            ).getLayoutValue(previousTransformInstance.transformEntity);
        // If previous transform is still running, set the start time to the previous transform's start time + config.value
        if (
            block.timestamp > previousTransformInstance.startTime + config.value
        ) {
            transformInstance.startTime = uint32(block.timestamp);
        } else {
            transformInstance.startTime =
                previousTransformInstance.startTime +
                config.value;
        }
        // Save the transform instance
        transformInstanceComponent.setLayoutValue(
            transformInstanceEntity,
            transformInstance
        );

        return (needsVrf, skipTransformInstance);
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function completeTransform(
        TransformInstanceComponentLayout memory transformInstance,
        uint256 transformInstanceEntity,
        uint256 randomWord
    )
        external
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (uint16 numSuccess, uint256 nextRandomWord)
    {
        numSuccess = transformInstance.count;
        // Get InstancEntity from tracker component
        TransformCraftingBuildingTrackerComponent trackerComponent = TransformCraftingBuildingTrackerComponent(
                _gameRegistry.getComponent(
                    TRANSFORM_CRAFTING_BUILDING_TRACKER_COMPONENT_ID
                )
            );
        uint256 instanceEntity = trackerComponent.getValue(
            transformInstanceEntity
        );
        // Remove transformInstanceEntity from tracker component
        trackerComponent.remove(transformInstanceEntity);
        // Remove transformInstanceEntity PendingIslandTransformListComponent list
        PendingIslandTransformListComponent pendingIslandTransformListComponent = PendingIslandTransformListComponent(
                _gameRegistry.getComponent(
                    PENDING_ISLAND_TRANSFORM_LIST_COMPONENT_ID
                )
            );
        uint256[]
            memory pendingCraftTransforms = pendingIslandTransformListComponent
                .getValue(instanceEntity);
        // Only remove if it is the first in the queue
        if (pendingCraftTransforms[0] != transformInstanceEntity) {
            revert NotFirstInQueue();
        }
        if (pendingCraftTransforms.length == 1) {
            pendingIslandTransformListComponent.removeValueAtIndex(
                instanceEntity,
                0
            );
        } else {
            // To keep the queue in order, remove the first transform and update the list
            uint256[] memory newPendingCraftTransforms = new uint256[](
                pendingCraftTransforms.length - 1
            );
            for (uint256 idx; idx < newPendingCraftTransforms.length; ++idx) {
                newPendingCraftTransforms[idx] = pendingCraftTransforms[
                    idx + 1
                ];
            }
            pendingIslandTransformListComponent.setValue(
                instanceEntity,
                newPendingCraftTransforms
            );
        }

        return (numSuccess, randomWord);
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function isTransformCompleteable(
        TransformInstanceComponentLayout memory transformInstance
    ) external view override returns (bool) {
        return _isCompleteable(transformInstance);
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function isTransformAvailable(
        address account,
        TransformParams calldata params
    ) external view override returns (bool) {
        uint256 transformEntity = params.transformEntity;

        // Prevent multiple transforms
        if (params.count != 1) {
            revert CannotExecuteMultipleTransform();
        }
        uint256 instanceEntity = abi.decode(params.data, (uint256));
        if (instanceEntity == 0) {
            revert InvalidInstanceEntity();
        }
        // Get owner of the island instance entity
        _checkCaller(instanceEntity, account);
        // Check if the transform is valid for the building
        _checkValidTransform(instanceEntity, transformEntity);

        return true;
    }

    /**
     * @dev Get the max queue slot count for a given building
     */
    function getMaxQueueSlotCount(
        uint256 instanceEntity
    ) public view returns (uint256 maxSlots) {
        maxSlots += CraftingSlotsGrantedComponent(
            _gameRegistry.getComponent(CRAFTING_SLOTS_GRANTED_COMPONENT_ID)
        ).getValue(_getObjectEntity(instanceEntity));
        if (maxSlots == 0) {
            revert ZeroSlotCount();
        }
        return maxSlots;
    }

    /** INTERNAL */

    /**
     * Validate completeTransform call
     * @dev Check time lock
     * @param transformInstance Instance of the transform entity
     */
    function _isCompleteable(
        TransformInstanceComponentLayout memory transformInstance
    ) internal view returns (bool) {
        uint32 timeLock = TransformConfigTimeLockComponent(
            _gameRegistry.getComponent(TRANSFORM_CONFIG_TIME_LOCK_COMPONENT_ID)
        ).getLayoutValue(transformInstance.transformEntity).value;

        // Check if Transform valid to end
        if (block.timestamp < transformInstance.startTime + timeLock) {
            return false;
        }

        return true;
    }

    /**
     * @dev Check if Crafting Building is public or private and if caller is allowed to call.
     * @param instanceEntity Unique guid of the CraftingBuilding on the island
     * @param caller Address of the caller
     */
    function _checkCaller(
        uint256 instanceEntity,
        address caller
    ) internal view returns (address) {
        uint256 islandEntity = SceneObjectParentComponent(
            _gameRegistry.getComponent(SCENE_OBJECT_PARENT_COMPONENT_ID)
        ).getValue(instanceEntity);
        if (islandEntity == 0) {
            revert BuildingNotFound();
        }
        address buildingOwner = EntityLibrary.entityToAddress(
            OwnerComponent(_gameRegistry.getComponent(OWNER_COMPONENT_ID))
                .getValue(islandEntity)
        );
        // Determine if CraftingBuilding is set as public or private
        if (
            PublicUseComponent(
                _gameRegistry.getComponent(PUBLIC_USE_COMPONENT_ID)
            ).getValue(instanceEntity) == 0
        ) {
            // Only owner may call if private
            if (buildingOwner != caller) {
                revert CraftingBuildingPrivate();
            }
        }
        return buildingOwner;
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

    /**
     * @dev Check if the transform is valid for the building
     */
    function _checkValidTransform(
        uint256 instanceEntity,
        uint256 transformEntity
    ) internal view {
        uint256 itemEntity = _getObjectEntity(instanceEntity);
        uint256[]
            memory validBuildings = CraftingBuildingTransformConfigComponent(
                _gameRegistry.getComponent(
                    CRAFTING_BUILDING_TRANSFORM_CONFIG_COMPONENT_ID
                )
            ).getLayoutValue(transformEntity).value;
        bool found = false;
        for (uint256 i = 0; i < validBuildings.length; i++) {
            if (validBuildings[i] == itemEntity) {
                found = true;
                break;
            }
        }
        if (!found) {
            revert InvalidTransformForBuilding();
        }
    }
}
