// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import {EntityLibrary} from "../core/EntityLibrary.sol";

import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";

import {ITransformRunnerSystem, TransformParams} from "./ITransformRunnerSystem.sol";
import {BaseTransformRunnerSystem, TransformInstanceComponentLayout} from "./BaseTransformRunnerSystem.sol";

import {Uint256Component, Layout as Uint256ComponentLayout, ID as UINT256_COMPONENT_ID} from "../generated/components/Uint256Component.sol";
import {PendingCraftingTransformListComponent, Layout as PendingCraftingTransformListComponentLayout, ID as PENDING_CRAFTING_TRANSFORM_LIST_COMPONENT_ID} from "../generated/components/PendingCraftingTransformListComponent.sol";
import {TransformConfigTimeLockComponent, Layout as TransformConfigTimeLockComponentLayout, ID as TRANSFORM_CONFIG_TIME_LOCK_COMPONENT_ID} from "../generated/components/TransformConfigTimeLockComponent.sol";
import {TransformInstanceComponent, Layout as TransformInstanceComponentLayout, ID as TRANSFORM_INSTANCE_COMPONENT_ID} from "../generated/components/TransformInstanceComponent.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.blacksmithtransformrunnersystem")
);

/**
 * @dev Global for tracking the max queue amount allowed for the blacksmith
 */
uint256 constant BLACKSMITH_MAX_QUEUE_AMOUNT = uint256(
    keccak256("game.piratenation.global.blacksmith.maxqueueamount")
);

/**
 * @title BlacksmithTransformRunnerSystem
 * @dev Handles the execution of transforms for the Blacksmith
 */
contract BlacksmithTransformRunnerSystem is BaseTransformRunnerSystem {
    /** ERRORS */

    /// @notice Exceeds Max Queue Slot
    error ExceedsMaxQueueSlot();

    /// @notice Cannot execute multiple transforms
    error CannotExecuteMultipleTransform();

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
        uint256 accountEntity = EntityLibrary.addressToEntity(
            transformInstance.account
        );
        PendingCraftingTransformListComponent pendingCraftingTransformListComponent = PendingCraftingTransformListComponent(
                _gameRegistry.getComponent(
                    PENDING_CRAFTING_TRANSFORM_LIST_COMPONENT_ID
                )
            );
        PendingCraftingTransformListComponentLayout
            memory pendingList = pendingCraftingTransformListComponent
                .getLayoutValue(accountEntity);
        // Check queue slot count is not exceeded
        if (
            pendingList.value.length + params.count >
            Uint256Component(_gameRegistry.getComponent(UINT256_COMPONENT_ID))
                .getLayoutValue(BLACKSMITH_MAX_QUEUE_AMOUNT)
                .value
        ) {
            revert ExceedsMaxQueueSlot();
        }
        uint256[] memory newInstances = new uint256[](1);
        newInstances[0] = transformInstanceEntity;
        pendingCraftingTransformListComponent.append(
            accountEntity,
            PendingCraftingTransformListComponentLayout(newInstances)
        );
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
        uint256 accountEntity = EntityLibrary.addressToEntity(
            transformInstance.account
        );

        // Remove transformInstanceEntity from PendingCraftingTransformListComponent list
        PendingCraftingTransformListComponent pendingCraftingTransformListComponent = PendingCraftingTransformListComponent(
                _gameRegistry.getComponent(
                    PENDING_CRAFTING_TRANSFORM_LIST_COMPONENT_ID
                )
            );
        uint256[]
            memory pendingCraftTransforms = pendingCraftingTransformListComponent
                .getValue(accountEntity);
        // Only remove if it is the first in the queue
        if (pendingCraftTransforms[0] != transformInstanceEntity) {
            revert NotFirstInQueue();
        }
        if (pendingCraftTransforms.length == 1) {
            pendingCraftingTransformListComponent.removeValueAtIndex(
                accountEntity,
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
            pendingCraftingTransformListComponent.setValue(
                accountEntity,
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
     * @dev Check time lock
     * @param transformInstance Instance of the transform entity
     */
    function _isCompleteable(
        TransformInstanceComponentLayout memory transformInstance
    ) internal view returns (bool) {
        TransformConfigTimeLockComponentLayout
            memory config = TransformConfigTimeLockComponent(
                _gameRegistry.getComponent(
                    TRANSFORM_CONFIG_TIME_LOCK_COMPONENT_ID
                )
            ).getLayoutValue(transformInstance.transformEntity);

        // Check if Transform valid to end
        if (block.timestamp < transformInstance.startTime + config.value) {
            return false;
        }

        return true;
    }
}
