// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import {ITransformRunnerSystem, TransformParams} from "./ITransformRunnerSystem.sol";
import {TransformInstanceComponent, Layout as TransformInstanceComponentLayout, ID as TRANSFORM_INSTANCE_COMPONENT_ID} from "../generated/components/TransformInstanceComponent.sol";
import {TransformInputComponent, Layout as TransformInputComponentLayout, ID as TRANSFORM_INPUT_COMPONENT_ID} from "../generated/components/TransformInputComponent.sol";
import {LootEntityArrayComponent, Layout as LootEntityArrayComponentLayout, ID as LOOT_ENTITY_ARRAY_COMPONENT_ID} from "../generated/components/LootEntityArrayComponent.sol";
import {TransformAccountDataComponent, Layout as TransformAccountDataComponentLayout, ID as TRANSFORM_ACCOUNT_DATA_COMPONENT_ID} from "../generated/components/TransformAccountDataComponent.sol";

import "../GameRegistryConsumerUpgradeable.sol";

abstract contract BaseTransformRunnerSystem is
    ITransformRunnerSystem,
    GameRegistryConsumerUpgradeable
{
    /** PUBLIC */

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function isTransformAvailable(
        address,
        TransformParams calldata
    ) external view virtual override returns (bool) {
        // No additional checks for this runner
        return true;
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function isTransformCompleteable(
        TransformInstanceComponentLayout memory
    ) external view virtual override returns (bool) {
        // By default all transforms are immediately completeable
        return true;
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function onTransformComplete(
        TransformInstanceComponentLayout memory,
        uint256,
        uint256 randomWord
    ) external virtual override returns (uint256) {
        // By default, do nothing
        return randomWord;
    }

    /** INTERNAL */

    /** @return Get the transform inputs from the transform definition entity */
    function _getTransformInputs(
        uint256 transformEntity
    ) internal view returns (TransformInputComponentLayout memory) {
        return
            TransformInputComponent(
                _gameRegistry.getComponent(TRANSFORM_INPUT_COMPONENT_ID)
            ).getLayoutValue(transformEntity);
    }

    /** @return Transform instance component */
    function _getTransformInstance(
        uint256 transformInstanceEntity
    ) internal view returns (TransformInstanceComponentLayout memory) {
        return
            TransformInstanceComponent(
                _gameRegistry.getComponent(TRANSFORM_INSTANCE_COMPONENT_ID)
            ).getLayoutValue(transformInstanceEntity);
    }

    /** @return Inputs for the transform instance. These were stored when the instance was created */
    function _getTransformInstanceInputs(
        uint256 transformInstanceEntity
    ) internal view returns (LootEntityArrayComponentLayout memory) {
        // Get transform instance component
        return
            LootEntityArrayComponent(
                _gameRegistry.getComponent(LOOT_ENTITY_ARRAY_COMPONENT_ID)
            ).getLayoutValue(transformInstanceEntity);
    }
}
