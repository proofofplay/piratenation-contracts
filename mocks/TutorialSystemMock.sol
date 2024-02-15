// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import {TutorialSystem} from "../checkpoint/TutorialSystem.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";

import {LootArrayComponent, Layout as LootArrayComponentStruct, ID as LOOT_ARRAY_COMPONENT_ID} from "../generated/components/LootArrayComponent.sol";
import {CheckpointComponent, Layout as CheckpointComponentStruct, ID as CHECKPOINT_COMPONENT_ID} from "../generated/components/CheckpointComponent.sol";
import {TutorialCheckpointComponent, Layout as TutorialCheckpointComponentStruct, ID as TUTORIAL_CHECKPOINT_COMPONENT_ID} from "../generated/components/TutorialCheckpointComponent.sol";

/** @title TutorialSystemMock for testnet */
contract TutorialSystemMock is TutorialSystem {
    function clearTutorialCheckpoint(
        uint256 checkpointEntityId,
        uint256 entityId
    ) external nonReentrant whenNotPaused {
        if (checkpointEntityId == 0 || entityId == 0) {
            revert InvalidInputs();
        }

        CheckpointComponentStruct memory checkpoint = CheckpointComponent(
            _gameRegistry.getComponent(CHECKPOINT_COMPONENT_ID)
        ).getLayoutValue(checkpointEntityId);
        // Ensure checkpoint exists
        if (checkpoint.numOfCheckpoints == 0) {
            revert CheckpointDoesNotExist(checkpointEntityId);
        }
        // Get the current tutorial checkpoint for the account
        TutorialCheckpointComponent tutorialCheckpointComponent = TutorialCheckpointComponent(
                _gameRegistry.getComponent(TUTORIAL_CHECKPOINT_COMPONENT_ID)
            );
        TutorialCheckpointComponentStruct
            memory tutorialCheckpoint = tutorialCheckpointComponent
                .getLayoutValue(entityId);

        // Clear TutorialCheckpoint
        tutorialCheckpoint.currentCheckpoint = 0;
        tutorialCheckpoint.tutorialCompleted = false;
        // Update the users current tutorial checkpoint
        tutorialCheckpointComponent.setLayoutValue(
            entityId,
            tutorialCheckpoint
        );
    }

    function mockMarkCheckpoint(
        uint256 checkpointEntityId
    ) external nonReentrant whenNotPaused {
        // Get user account
        address account = _getPlayerAccount(_msgSender());
        uint256 entityId = EntityLibrary.addressToEntity(account);
        _markTutorialCheckpoint(checkpointEntityId, entityId);
    }
}
