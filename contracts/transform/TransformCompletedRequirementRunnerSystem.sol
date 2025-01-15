// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import {EntityLibrary} from "../core/EntityLibrary.sol";
import {TransformLibrary} from "../transform/TransformLibrary.sol";

import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";

import {ITransformRunnerSystem, TransformParams} from "./ITransformRunnerSystem.sol";
import {BaseTransformRunnerSystem, TransformInstanceComponentLayout} from "./BaseTransformRunnerSystem.sol";

import {TransformCompletedRequirementConfigComponent, Layout as TransformCompletedRequirementConfigComponentLayout, ID as TRANSFORM_COMPLETED_REQUIREMENT_COMPONENT_ID} from "../generated/components/TransformCompletedRequirementConfigComponent.sol";
import {TransformAccountDataComponent, Layout as TransformAccountDataComponentLayout, ID as TRANSFORM_ACCOUNT_DATA_COMPONENT_ID} from "../generated/components/TransformAccountDataComponent.sol";
import {TransformInstanceComponent, Layout as TransformInstanceComponentLayout, ID as TRANSFORM_INSTANCE_COMPONENT_ID} from "../generated/components/TransformInstanceComponent.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.transformcompletedrequirementrunnersystem")
);

/**
 * @title TransformCompletedRequirementRunnerSystem
 * @dev Handles the execution of transforms based on the completions of the previous transforms
 */
contract TransformCompletedRequirementRunnerSystem is BaseTransformRunnerSystem {
    /** ERRORS */

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
        TransformInstanceComponentLayout memory,
        uint256,
        TransformParams calldata params
    )
        external
        view
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (bool needsVrf, bool skipTransformInstance)
    {
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
        // Success by default
        numSuccess = transformInstance.count;
        nextRandomWord = randomWord;
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function isTransformCompleteable(
        TransformInstanceComponentLayout memory transformInstance
    ) external view override returns (bool) {
        return _areRequirementsFulfilled(transformInstance.account, transformInstance.transformEntity);
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function isTransformAvailable(
        address account,
        TransformParams calldata params
    ) external view override returns (bool) {
        return _areRequirementsFulfilled(account, params.transformEntity);
    }

    /** INTERNAL */
    /**
     * Checks if transform requirements are fullfilled based on the TransformCompletedRequirementConfigComponent
     * If the number of completions on this account is less than the number of completions required, return false
     * If the number of completions on this account is greater than or equal to the number of completions required, return true
     * @param account The account to check
     * @param transformEntity transform entity to check requirement for
     */
    function _areRequirementsFulfilled(
        address account,
        uint256 transformEntity
    ) internal view returns (bool) {
        TransformCompletedRequirementConfigComponentLayout memory config = TransformCompletedRequirementConfigComponent(
                _gameRegistry.getComponent(TRANSFORM_COMPLETED_REQUIREMENT_COMPONENT_ID)
            ).getLayoutValue(
                transformEntity
            );

        for (uint256 i = 0; i < config.entityRequirements.length; i++) {
            uint256 entityRequirement = config.entityRequirements[i];
            uint32 countRequirement = config.countRequirements[i];
            
            if (TransformLibrary
                    .getAccountTransformData(
                        _gameRegistry,
                        account,
                        entityRequirement
                    ).numCompletions < countRequirement) {
                return false;
            }
        }
        return true;
    }
}
