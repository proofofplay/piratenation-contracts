// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.26;

import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";

import {LivesSystem, ID as LIVES_SYSTEM_ID} from "../lives/LivesSystem.sol";
import {ITransformRunnerSystem, TransformParams} from "./ITransformRunnerSystem.sol";
import {BaseTransformRunnerSystem, TransformInstanceComponentLayout} from "./BaseTransformRunnerSystem.sol";
import {EntityBaseComponent, ID as ENTITY_BASE_COMPONENT_ID} from "../generated/components/EntityBaseComponent.sol";
import {TransformInstanceComponent, Layout as TransformInstanceComponentLayout, ID as TRANSFORM_INSTANCE_COMPONENT_ID} from "../generated/components/TransformInstanceComponent.sol";
import {LivesTransformConfigComponent, Layout as LivesTransformConfigComponentLayout, ID as LIVES_TRANSFORM_CONFIG_COMPONENT_ID} from "../generated/components/LivesTransformConfigComponent.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.livestransformrunner")
);

/** ERRORS */

/// @notice Invalid lives transform config
error InvalidLivesTransformConfig();

/**
 * @title LivesTransformRunner
 * @dev Handles the execution of transforms that add or subtract lives
 */
contract LivesTransformRunner is BaseTransformRunnerSystem {
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
        // Get the lives transform config component
        LivesTransformConfigComponentLayout
            memory config = LivesTransformConfigComponent(
                _gameRegistry.getComponent(LIVES_TRANSFORM_CONFIG_COMPONENT_ID)
            ).getLayoutValue(transformInstance.transformEntity);
        if (config.livesType == 0) {
            revert InvalidLivesTransformConfig();
        }
        LivesSystem livesSystem = LivesSystem(
            _gameRegistry.getSystem(LIVES_SYSTEM_ID)
        );
        if (config.livesToSubtract > 0) {
            livesSystem.subtractLives(
                transformInstance.account,
                config.livesType,
                config.livesToSubtract
            );
        } else if (config.livesToAdd > 0) {
            livesSystem.addLives(
                transformInstance.account,
                config.livesType,
                config.livesToAdd
            );
        }
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
        return (numSuccess, randomWord);
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
    ) external pure override returns (bool) {
        return true;
    }
}
