// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {LootArrayComponentLibrary} from "../loot/LootArrayComponentLibrary.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {ILootSystem} from "../loot/ILootSystem.sol";

import {LootArrayComponent, Layout as LootArrayComponentStruct, ID as LOOT_ARRAY_COMPONENT_ID} from "../generated/components/LootArrayComponent.sol";
import {CheckpointComponent, Layout as CheckpointComponentStruct, ID as CHECKPOINT_COMPONENT_ID} from "../generated/components/CheckpointComponent.sol";
import {TutorialCheckpointComponent, Layout as TutorialCheckpointComponentStruct, ID as TUTORIAL_CHECKPOINT_COMPONENT_ID} from "../generated/components/TutorialCheckpointComponent.sol";
import {EnabledComponent, ID as ENABLED_COMPONENT_ID} from "../generated/components/EnabledComponent.sol";

import {MANAGER_ROLE, TRUSTED_FORWARDER_ROLE} from "../Constants.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.tutorialsystem"));

struct TutorialCheckpointDefinition {
    // Checkpoint Component ID
    uint256 checkpointEntityId;
    // Number of checkpoints
    uint64 numOfCheckpoints;
    // Checkpoint position
    uint64 checkpointPosition;
    // Checkpoint enabled
    bool enabled;
    // Checkpoint reward
    ILootSystem.Loot[] checkpointReward;
}

contract TutorialSystem is GameRegistryConsumerUpgradeable {
    /** ERRORS */

    /// @notice Error when invalid zero inputs used
    error InvalidInputs();

    error CheckpointDoesNotExist(uint256 checkpointId);

    /// @notice Error when tutorial is already completed
    error AlreadyCompleted();

    /// @notice Error when tutorial checkpoint is not enabled
    error CheckpointNotEnabled(uint256 checkpointId);

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /** SETTERS */

    function setTutorialCheckpoint(
        TutorialCheckpointDefinition calldata definition
    ) external onlyRole(MANAGER_ROLE) {
        // Check valid inputs
        if (
            definition.checkpointEntityId == 0 ||
            definition.numOfCheckpoints == 0 ||
            definition.checkpointPosition == 0
        ) {
            revert InvalidInputs();
        }
        if (definition.checkpointPosition > definition.numOfCheckpoints) {
            revert InvalidInputs();
        }
        // Set CheckpointComponent
        CheckpointComponent(_gameRegistry.getComponent(CHECKPOINT_COMPONENT_ID))
            .setLayoutValue(
                definition.checkpointEntityId,
                CheckpointComponentStruct(
                    definition.numOfCheckpoints,
                    definition.checkpointPosition,
                    EntityLibrary.addressToEntity(address(this))
                )
            );
        // If Checkpoint doesnt have a lootset set, check if one exists and remove it to clear out any associated lootset
        LootArrayComponent lootArrayComponent = LootArrayComponent(
            _gameRegistry.getComponent(LOOT_ARRAY_COMPONENT_ID)
        );
        if (definition.checkpointReward.length == 0) {
            LootArrayComponentStruct memory lootArray = lootArrayComponent
                .getLayoutValue(definition.checkpointEntityId);
            if (lootArray.lootType.length > 0) {
                lootArrayComponent.remove(definition.checkpointEntityId);
            }
        }
        // Set Checkpoint reward in LootArrayComponent if exists
        if (definition.checkpointReward.length > 0) {
            (
                uint32[] memory lootType,
                address[] memory tokenContract,
                uint256[] memory lootId,
                uint256[] memory amount
            ) = LootArrayComponentLibrary.convertLootToArrays(
                    definition.checkpointReward
                );
            lootArrayComponent.setLayoutValue(
                definition.checkpointEntityId,
                LootArrayComponentStruct(
                    lootType,
                    tokenContract,
                    lootId,
                    amount
                )
            );
        }
        // Set Tutorial checkpoint enabled status
        EnabledComponent(_gameRegistry.getComponent(ENABLED_COMPONENT_ID))
            .setValue(definition.checkpointEntityId, definition.enabled);
    }

    /**
     * @dev Add a Checkpoint to the CheckpointComponent
     * @param checkpointEntityId Checkpoint struct containing the Checkpoint definition
     * @param entityId Entity of account to mark tutorial checkpoint for
     */
    function markTutorialCheckpoint(
        uint256 checkpointEntityId,
        uint256 entityId
    ) external nonReentrant whenNotPaused onlyRole(TRUSTED_FORWARDER_ROLE) {
        _markTutorialCheckpoint(checkpointEntityId, entityId);
    }

    /** INTERNAL */

    function _markTutorialCheckpoint(
        uint256 checkpointEntityId,
        uint256 entityId
    ) internal {
        if (checkpointEntityId == 0 || entityId == 0) {
            revert InvalidInputs();
        }
        // Check if checkpoint is enabled
        bool enabled = EnabledComponent(
            _gameRegistry.getComponent(ENABLED_COMPONENT_ID)
        ).getValue(checkpointEntityId);
        if (!enabled) {
            revert CheckpointNotEnabled(checkpointEntityId);
        }

        CheckpointComponentStruct memory checkpoint = CheckpointComponent(
            _gameRegistry.getComponent(CHECKPOINT_COMPONENT_ID)
        ).getLayoutValue(checkpointEntityId);
        // Ensure checkpoint exists and calling TutorialSystem checkpoint
        if (
            checkpoint.numOfCheckpoints == 0 ||
            checkpoint.groupId != EntityLibrary.addressToEntity(address(this))
        ) {
            revert CheckpointDoesNotExist(checkpointEntityId);
        }
        // Get the current tutorial checkpoint for the account
        TutorialCheckpointComponent tutorialCheckpointComponent = TutorialCheckpointComponent(
                _gameRegistry.getComponent(TUTORIAL_CHECKPOINT_COMPONENT_ID)
            );
        TutorialCheckpointComponentStruct
            memory tutorialCheckpoint = tutorialCheckpointComponent
                .getLayoutValue(entityId);
        // Ensure user is still at the previous checkpoint or has not already completed the tutorial
        if (
            tutorialCheckpoint.currentCheckpoint !=
            checkpoint.checkpointPosition - 1 ||
            tutorialCheckpoint.tutorialCompleted == true
        ) {
            revert AlreadyCompleted();
        }
        // Increment the current checkpoint for the user
        tutorialCheckpoint.currentCheckpoint++;
        // If the user has reached the last checkpoint, mark the tutorial as completed
        if (
            tutorialCheckpoint.currentCheckpoint == checkpoint.numOfCheckpoints
        ) {
            tutorialCheckpoint.tutorialCompleted = true;
        }
        // Update the users current tutorial checkpoint
        tutorialCheckpointComponent.setLayoutValue(
            entityId,
            tutorialCheckpoint
        );
        ILootSystem.Loot[] memory loot = LootArrayComponentLibrary
            .convertLootArrayToLootSystem(
                _gameRegistry.getComponent(LOOT_ARRAY_COMPONENT_ID),
                checkpointEntityId
            );
        // If the checkpoint has a reward, mint it to the user
        if (loot.length > 0) {
            _lootSystem().grantLoot(
                EntityLibrary.entityToAddress(entityId),
                loot
            );
        }
    }
}
