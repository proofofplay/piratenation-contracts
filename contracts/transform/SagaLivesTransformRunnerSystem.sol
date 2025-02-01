// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.26;

import {EntityLibrary} from "../core/EntityLibrary.sol";
import {TransformLibrary} from "../transform/TransformLibrary.sol";

import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";

import {SagaLivesSystem, ID as SAGA_LIVES_SYSTEM_ID} from "../dungeons/SagaLivesSystem.sol";
import {SagaLivesTransformTrackerComponent, Layout as SagaLivesTransformTrackerComponentLayout, ID as SAGA_LIVES_TRANSFORM_TRACKER_COMPONENT_ID} from "../generated/components/SagaLivesTransformTrackerComponent.sol";
import {ITransformRunnerSystem, TransformParams} from "./ITransformRunnerSystem.sol";
import {BaseTransformRunnerSystem, TransformInstanceComponentLayout} from "./BaseTransformRunnerSystem.sol";

import {TransformInstanceComponent, Layout as TransformInstanceComponentLayout, ID as TRANSFORM_INSTANCE_COMPONENT_ID} from "../generated/components/TransformInstanceComponent.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.sagalivestransformrunnersystem")
);

/** ERRORS */

/// @notice Invalid count parameters
error InvalidCountParameters();

/// @notice Invalid saga transform
error InvalidSagaTransform();

/**
 * @title SagaLivesTransformRunnerSystem
 * @dev Handles the execution of transforms that have saga lives requirements
 */
contract SagaLivesTransformRunnerSystem is BaseTransformRunnerSystem {
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
        bool successfulRound = abi.decode(params.data, (bool));
        SagaLivesTransformTrackerComponent(
            _gameRegistry.getComponent(
                SAGA_LIVES_TRANSFORM_TRACKER_COMPONENT_ID
            )
        ).setValue(
                transformInstanceEntity,
                transformInstance.transformEntity,
                successfulRound
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
        SagaLivesTransformTrackerComponentLayout
            memory transformTracker = SagaLivesTransformTrackerComponent(
                _gameRegistry.getComponent(
                    SAGA_LIVES_TRANSFORM_TRACKER_COMPONENT_ID
                )
            ).getLayoutValue(transformInstanceEntity);
        if (
            transformTracker.transformEntity !=
            transformInstance.transformEntity ||
            transformTracker.transformEntity == 0
        ) {
            revert InvalidSagaTransform();
        }
        if (transformTracker.success) {
            numSuccess = transformInstance.count;
            nextRandomWord = randomWord;
            return (numSuccess, nextRandomWord);
        } else {
            SagaLivesSystem(_gameRegistry.getSystem(SAGA_LIVES_SYSTEM_ID))
                .spendLives(
                    EntityLibrary.addressToEntity(transformInstance.account),
                    transformInstance.count
                );
            numSuccess = 0;
            nextRandomWord = 0;
        }
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function isTransformCompleteable(
        TransformInstanceComponentLayout memory
    ) external pure override returns (bool) {
        return true;
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function isTransformAvailable(
        address account,
        TransformParams calldata params
    ) external view override returns (bool) {
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        uint256 sagaLives = SagaLivesSystem(
            _gameRegistry.getSystem(SAGA_LIVES_SYSTEM_ID)
        ).getLives(accountEntity);
        if (params.count > 1) {
            revert InvalidCountParameters();
        }
        if (sagaLives > 0) {
            return true;
        }
        return false;
    }
}
