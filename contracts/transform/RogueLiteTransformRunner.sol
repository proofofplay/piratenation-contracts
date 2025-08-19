// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.26;

import {EntityLibrary} from "../core/EntityLibrary.sol";
import {TransformLibrary} from "../transform/TransformLibrary.sol";

import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";

import {LastTransformTrackerComponent, Layout as LastTransformTrackerComponentLayout, ID as LAST_TRANSFORM_TRACKER_COMPONENT_ID} from "../generated/components/LastTransformTrackerComponent.sol";
import {ITransformRunnerSystem, TransformParams} from "./ITransformRunnerSystem.sol";
import {BaseTransformRunnerSystem, TransformInstanceComponentLayout} from "./BaseTransformRunnerSystem.sol";
import {TransformCompletedRequirementConfigComponent, Layout as TransformCompletedRequirementConfigComponentLayout, ID as TRANSFORM_COMPLETED_REQUIREMENT_COMPONENT_ID} from "../generated/components/TransformCompletedRequirementConfigComponent.sol";
import {EntityBaseComponent, ID as ENTITY_BASE_COMPONENT_ID} from "../generated/components/EntityBaseComponent.sol";
import {TransformInstanceComponent, Layout as TransformInstanceComponentLayout, ID as TRANSFORM_INSTANCE_COMPONENT_ID} from "../generated/components/TransformInstanceComponent.sol";
import {IGameItems, ID as GAME_ITEMS_ID} from "../tokens/gameitems/IGameItems.sol";
import {Uint256Component, ID as UINT256_COMPONENT_ID} from "../generated/components/Uint256Component.sol";
import {LastCombatTrackerComponent, Layout as LastCombatTrackerComponentLayout, ID as LAST_COMBAT_TRACKER_COMPONENT_ID} from "../generated/components/LastCombatTrackerComponent.sol";
import {TimeRangeLibrary} from "../core/TimeRangeLibrary.sol";
import {ID as TIME_RANGE_COMPONENT_ID} from "../generated/components/TimeRangeComponent.sol";
import {ScoreComponent, ID as SCORE_COMPONENT_ID} from "../generated/components/ScoreComponent.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.roguelitetransformrunner")
);

// Rogue-lite trophy progression ID
uint256 constant ROGUE_LITE_PROGRESSION = uint256(
    keccak256("game.piratenation.global.rogue_lite_progression")
);

// Rogue-lite total score ID
uint256 constant ROGUE_LITE_TOTAL_SCORE = uint256(
    keccak256("game.piratenation.global.rogue_lite_total_score")
);

// Rogue-lite gated transform ID
uint256 constant ROGUE_LITE_GATED_TRANSFORM = uint256(
    keccak256("game.piratenation.global.rogue_lite_gated")
);

/** ERRORS */

/// @notice Did not complete previous transform
error DidNotCompletePreviousTransform();

/// @notice No rogue-lite season id set
error NoRogueLiteSeasonIdSet();

/// @notice Previous battle not completed
error PreviousBattleNotCompleted();

/** STRUCTS **/

struct BattleData {
    bool battleWon;
    uint256 totalScore;
    uint256 pirateEntity;
    uint256 shipEntity;
    uint256 shipHealth;
    string[] cardsToPersist;
}

/**
 * @title RogueLiteTransformRunner
 * @dev Handles the execution of transforms that have rogue-lite feature
 */
contract RogueLiteTransformRunner is BaseTransformRunnerSystem {
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
        returns (bool, bool)
    {
        // Get the transform tracker component
        LastTransformTrackerComponent lastTransformTrackerComponent = LastTransformTrackerComponent(
                _gameRegistry.getComponent(LAST_TRANSFORM_TRACKER_COMPONENT_ID)
            );
        // Current Rogue-lite season running
        if (
            EntityBaseComponent(
                _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
            ).getValue(ID) == 0
        ) {
            revert NoRogueLiteSeasonIdSet();
        }
        uint256 rogueLiteAccountEntity = EntityLibrary.accountSubEntity(
            transformInstance.account,
            EntityBaseComponent(
                _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
            ).getValue(ID)
        );
        // Check if the transform is a Rogue-lite gated transform
        if (
            EntityBaseComponent(
                _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
            ).getValue(ROGUE_LITE_GATED_TRANSFORM) ==
            transformInstance.transformEntity
        ) {
            // Set the last transform tracker
            lastTransformTrackerComponent.setValue(
                rogueLiteAccountEntity,
                transformInstance.transformEntity,
                true
            );
            // Record the last combat data
            LastCombatTrackerComponent(
                _gameRegistry.getComponent(LAST_COMBAT_TRACKER_COMPONENT_ID)
            ).setLayoutValue(
                    EntityLibrary.addressToEntity(transformInstance.account),
                    LastCombatTrackerComponentLayout({
                        transformInstanceEntity: transformInstanceEntity,
                        pirateEntity: 0,
                        shipEntity: 0,
                        shipHealth: 0,
                        cardsToPersist: new string[](0)
                    })
                );
            // Clear out the score component
            ScoreComponent(_gameRegistry.getComponent(SCORE_COMPONENT_ID))
                .remove(
                    EntityLibrary.accountSubEntity(
                        transformInstance.account,
                        EntityBaseComponent(
                            _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
                        ).getValue(ID)
                    )
                );
            // Return immediately
            return (false, false);
        }

        // Get the transform completed requirement config component
        TransformCompletedRequirementConfigComponentLayout
            memory config = TransformCompletedRequirementConfigComponent(
                _gameRegistry.getComponent(
                    TRANSFORM_COMPLETED_REQUIREMENT_COMPONENT_ID
                )
            ).getLayoutValue(transformInstance.transformEntity);
        // If the transform has a previous transform requirement, check if it has been completed
        if (config.entityRequirements.length > 0) {
            // Get the last transform tracker data and check if the previous transform is equal to the last transform required
            LastTransformTrackerComponentLayout
                memory lastTransformTracker = lastTransformTrackerComponent
                    .getLayoutValue(rogueLiteAccountEntity);
            if (
                lastTransformTracker.transformEntity !=
                config.entityRequirements[0]
            ) {
                revert DidNotCompletePreviousTransform();
            }
            // If it is then check if the previous battle was completed
            if (lastTransformTracker.success == false) {
                revert PreviousBattleNotCompleted();
            }
        }

        // Game server passes data as a boolean, true if battle won and false if battle lost
        BattleData memory battleData = abi.decode(params.data, (BattleData));
        if (
            battleData.battleWon == true &&
            TimeRangeLibrary.checkWithinTimeRange(
                _gameRegistry.getComponent(TIME_RANGE_COMPONENT_ID),
                EntityBaseComponent(
                    _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
                ).getValue(ID)
            )
        ) {
            // Only handle trophies if the season is active and the battle was won
            _handleTrophies(battleData.totalScore, transformInstance.account);
        }
        // Set the last transform tracker
        lastTransformTrackerComponent.setValue(
            rogueLiteAccountEntity,
            transformInstance.transformEntity,
            battleData.battleWon
        );
        // Record the last combat data
        LastCombatTrackerComponent(
            _gameRegistry.getComponent(LAST_COMBAT_TRACKER_COMPONENT_ID)
        ).setLayoutValue(
                EntityLibrary.addressToEntity(transformInstance.account),
                LastCombatTrackerComponentLayout({
                    transformInstanceEntity: transformInstanceEntity,
                    pirateEntity: battleData.pirateEntity,
                    shipEntity: battleData.shipEntity,
                    shipHealth: battleData.shipHealth,
                    cardsToPersist: battleData.cardsToPersist
                })
            );

        return (false, false);
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
        uint256 rogueLiteAccountEntity = EntityLibrary.accountSubEntity(
            transformInstance.account,
            EntityBaseComponent(
                _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
            ).getValue(ID)
        );
        // Get the transform tracker component
        LastTransformTrackerComponent lastTransformTrackerComponent = LastTransformTrackerComponent(
                _gameRegistry.getComponent(LAST_TRANSFORM_TRACKER_COMPONENT_ID)
            );
        // Get the last transform tracker data
        LastTransformTrackerComponentLayout
            memory lastTransformTracker = lastTransformTrackerComponent
                .getLayoutValue(rogueLiteAccountEntity);
        // If the battle was lost then set numSuccess to 0 so that rewards are not given
        if (lastTransformTracker.success == false) {
            numSuccess = 0;
        } else {
            numSuccess = transformInstance.count;
        }
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
    ) external view override returns (bool) {
        if (params.count != 1) {
            return false;
        }
        // Get the transform tracker component
        LastTransformTrackerComponent lastTransformTrackerComponent = LastTransformTrackerComponent(
                _gameRegistry.getComponent(LAST_TRANSFORM_TRACKER_COMPONENT_ID)
            );
        // Current Rogue-lite season running
        if (
            EntityBaseComponent(
                _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
            ).getValue(ID) == 0
        ) {
            return false;
        }
        uint256 rogueLiteAccountEntity = EntityLibrary.accountSubEntity(
            account,
            EntityBaseComponent(
                _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
            ).getValue(ID)
        );
        // Get the transform completed requirement config component
        TransformCompletedRequirementConfigComponentLayout
            memory config = TransformCompletedRequirementConfigComponent(
                _gameRegistry.getComponent(
                    TRANSFORM_COMPLETED_REQUIREMENT_COMPONENT_ID
                )
            ).getLayoutValue(params.transformEntity);
        // If the transform has a previous transform requirement, check if it has been completed
        if (config.entityRequirements.length > 0) {
            // Get the last transform tracker data and check if the previous transform is equal to the last transform required
            LastTransformTrackerComponentLayout
                memory lastTransformTracker = lastTransformTrackerComponent
                    .getLayoutValue(rogueLiteAccountEntity);
            if (
                lastTransformTracker.transformEntity !=
                config.entityRequirements[0]
            ) {
                return false;
            }
            // If it is then check if the previous battle was completed
            if (lastTransformTracker.success == false) {
                return false;
            }
        }
        return true;
    }

    /**
     * @notice Handles the trophies for the Rogue-lite transform runner
     * @param totalScore The total score of the last battle
     * @param account The account of the player
     */
    function _handleTrophies(uint256 totalScore, address account) internal {
        // Get the tokenId of the RogueLite Progression Trophy
        uint256 progressionTokenEntity = EntityBaseComponent(
            _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
        ).getValue(ROGUE_LITE_PROGRESSION);
        uint256 totalScoreTokenEntity = EntityBaseComponent(
            _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
        ).getValue(ROGUE_LITE_TOTAL_SCORE);
        // If there is a progression aka highest scoretrophy token, mint it
        if (progressionTokenEntity > 0) {
            (, uint256 tokenId) = EntityLibrary.entityToToken(
                progressionTokenEntity
            );
            uint256 scoreTrackerEntity = EntityLibrary.accountSubEntity(
                account,
                EntityBaseComponent(
                    _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
                ).getValue(ID)
            );
            ScoreComponent scoreComponent = ScoreComponent(
                _gameRegistry.getComponent(SCORE_COMPONENT_ID)
            );
            uint256 newSumScore = scoreComponent.getValue(scoreTrackerEntity) +
                totalScore;
            scoreComponent.setValue(scoreTrackerEntity, newSumScore);
            uint256 currentTrophies = IGameItems(
                _gameRegistry.getSystem(GAME_ITEMS_ID)
            ).balanceOf(account, tokenId);
            // Only mint if current progression trophy marker is greater than current trophies
            if (newSumScore > 0 && newSumScore > currentTrophies) {
                // burn old trophy amount
                IGameItems(_gameRegistry.getSystem(GAME_ITEMS_ID)).burn(
                    account,
                    tokenId,
                    currentTrophies
                );
                // mint new trophy amount
                IGameItems(_gameRegistry.getSystem(GAME_ITEMS_ID)).mint(
                    account,
                    tokenId,
                    newSumScore
                );
            }
        }
        // If there is a total score token, update it
        if (totalScoreTokenEntity > 0) {
            (, uint256 tokenId) = EntityLibrary.entityToToken(
                totalScoreTokenEntity
            );
            IGameItems(_gameRegistry.getSystem(GAME_ITEMS_ID)).mint(
                account,
                tokenId,
                totalScore
            );
        }
    }
}
