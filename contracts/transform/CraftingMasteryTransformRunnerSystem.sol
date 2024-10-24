// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import {EntityLibrary} from "../core/EntityLibrary.sol";

import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";

import {ITransformRunnerSystem, TransformParams} from "./ITransformRunnerSystem.sol";
import {BaseTransformRunnerSystem, TransformInstanceComponentLayout} from "./BaseTransformRunnerSystem.sol";
import {CraftingMasteryConfigComponent, Layout as CraftingMasteryConfigComponentLayout, ID as CRAFTING_MASTERY_CONFIG_COMPONENT_ID} from "../generated/components/CraftingMasteryConfigComponent.sol";
import {CounterComponent, Layout as CounterComponentLayout, ID as COUNTER_COMPONENT_ID} from "../generated/components/CounterComponent.sol";
import {EntityBaseComponent, Layout as EntityBaseComponentLayout, ID as ENTITY_BASE_COMPONENT_ID} from "../generated/components/EntityBaseComponent.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.craftingmasterytransformrunnersystem")
);

/**
 * @title CraftingMasteryTransformRunnerSystem
 * @dev Handles the execution of transforms for the Crafting Mastery feature
 */
contract CraftingMasteryTransformRunnerSystem is BaseTransformRunnerSystem {
    /** ERRORS */

    /// @notice Exceeds Max Queue Slot
    error NoCraftingMasteryConfig();

    /// @notice No Entity Base Component
    error NoEntityBaseComponent();

    /// @notice Requires Mastery Reached
    error RequiresMasteryReached();

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
        view
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (bool needsVrf, bool skipTransformInstance)
    {
        EntityBaseComponent entityBaseComponent = EntityBaseComponent(
            _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
        );
        if (!entityBaseComponent.has(params.transformEntity)) {
            revert NoEntityBaseComponent();
        }
        uint256 entityBase = entityBaseComponent.getValue(
            params.transformEntity
        );
        CraftingMasteryConfigComponent craftingMasteryConfigComponent = CraftingMasteryConfigComponent(
                _gameRegistry.getComponent(CRAFTING_MASTERY_CONFIG_COMPONENT_ID)
            );
        if (!craftingMasteryConfigComponent.has(entityBase)) {
            revert NoCraftingMasteryConfig();
        }
        CraftingMasteryConfigComponentLayout
            memory config = CraftingMasteryConfigComponent(
                _gameRegistry.getComponent(CRAFTING_MASTERY_CONFIG_COMPONENT_ID)
            ).getLayoutValue(params.transformEntity);
        // If transform is mastery gated and user has not reached mastery, revert
        if (config.requireMasteryReached) {
            uint256 currentUserMasteryCount = CounterComponent(
                _gameRegistry.getComponent(COUNTER_COMPONENT_ID)
            ).getValue(
                    EntityLibrary.accountSubEntity(
                        transformInstance.account,
                        entityBase
                    )
                );
            if (currentUserMasteryCount < config.masteryLimit) {
                revert RequiresMasteryReached();
            }
        }

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
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (uint16 numSuccess, uint256 nextRandomWord)
    {
        numSuccess = transformInstance.count;
        // Track count of mastery points granted per entity base
        uint256 entityBase = EntityBaseComponent(
            _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
        ).getValue(transformInstance.transformEntity);
        uint256 accountSubEntity = EntityLibrary.accountSubEntity(
            transformInstance.account,
            entityBase
        );
        CraftingMasteryConfigComponentLayout
            memory config = CraftingMasteryConfigComponent(
                _gameRegistry.getComponent(CRAFTING_MASTERY_CONFIG_COMPONENT_ID)
            ).getLayoutValue(entityBase);
        CounterComponent counterComponent = CounterComponent(
            _gameRegistry.getComponent(COUNTER_COMPONENT_ID)
        );
        uint256 currentUserMasteryCount = counterComponent.getValue(
            accountSubEntity
        );
        if (currentUserMasteryCount >= config.masteryLimit) {
            return (numSuccess, randomWord);
        }
        // Make sure not to exceed max mastery points
        if (
            currentUserMasteryCount + config.masteryPointsGranted >
            config.masteryLimit
        ) {
            currentUserMasteryCount = config.masteryLimit;
        } else {
            currentUserMasteryCount += config.masteryPointsGranted;
        }
        counterComponent.setValue(accountSubEntity, currentUserMasteryCount);

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
        TransformParams calldata
    ) external pure override returns (bool) {
        return true;
    }

    /** INTERNAL */

    /**
     * Validate completeTransform call
     * @dev Check time lock
     */
    function _isCompleteable(
        TransformInstanceComponentLayout memory
    ) internal pure returns (bool) {
        return true;
    }
}
