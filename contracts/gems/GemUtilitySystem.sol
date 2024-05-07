// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import {ID, IGemUtilitySystem} from "./IGemUtilitySystem.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";

import {EntityLibrary} from "../core/EntityLibrary.sol";
import {TransformLibrary} from "../transform/TransformLibrary.sol";

import {TransformParams} from "../transform/ITransformRunnerSystem.sol";
import {TransformInstanceComponent, Layout as TransformInstanceComponentLayout, ID as TRANSFORM_INSTANCE_COMPONENT_ID} from "../generated/components/TransformInstanceComponent.sol";
import {TransformInputComponent, Layout as TransformInputComponentLayout, ID as TRANSFORM_INPUT_COMPONENT_ID} from "../generated/components/TransformInputComponent.sol";
import {GemResourceCostComponent, Layout as GemsResourceCostComponentLayout, ID as GEM_RESOURCE_COST_COMPONENT_ID} from "../generated/components/GemResourceCostComponent.sol";
import {GemTransformEligibleComponent, Layout as GemTransformEligibleComponentLayout, ID as GEM_TRANSFORM_ELIGIBLE_COMPONENT_ID} from "../generated/components/GemTransformEligibleComponent.sol";
import {DefaultTransformRunnerConfigComponent, Layout as DefaultTransformRunnerConfigComponentLayout, ID as DEFAULT_TRANSFORM_RUNNER_CONFIG_COMPONENT_ID} from "../generated/components/DefaultTransformRunnerConfigComponent.sol";
import {BountyTransformConfigComponent, Layout as BountyTransformConfigComponentLayout, ID as BOUNTY_TRANSFORM_CONFIG_COMPONENT_ID} from "../generated/components/BountyTransformConfigComponent.sol";
import {TransformAccountDataComponent, Layout as TransformAccountDataComponentLayout, ID as TRANSFORM_ACCOUNT_DATA_COMPONENT_ID} from "../generated/components/TransformAccountDataComponent.sol";
import {PirateTransformRunnerConfigComponent, Layout as PirateTransformRunnerConfigComponentLayout, ID as PIRATE_QUEST_RUNNER_CONFIG_COMPONENT_ID} from "../generated/components/PirateTransformRunnerConfigComponent.sol";
import {EntityListComponent, Layout as EntityListComponentLayout, ID as ENTITY_LIST_COMPONENT_ID} from "../generated/components/EntityListComponent.sol";
import {ParentComponent, ID as PARENT_COMPONENT_ID} from "../generated/components/ParentComponent.sol";
import {RangeComponent, Layout as RangeComponentLayout, ID as RANGE_COMPONENT_ID} from "../generated/components/RangeComponent.sol";
import {GemFormulaComponent, Layout as GemFormulaComponentLayout, ID as GEM_FORMULA_COMPONENT_ID} from "../generated/components/GemFormulaComponent.sol";
import {GemCostMultiplierComponent, Layout as GemCostMultiplierComponentLayout, ID as GEM_COST_MULTIPLIER_COMPONENT_ID} from "../generated/components/GemCostMultiplierComponent.sol";
import {GemTransformCooldownEligibleComponent, Layout as GemTransformCooldownEligibleComponentLayout, ID as GEM_TRANSFORM_COOLDOWN_ELIGIBLE_COMPONENT_ID} from "../generated/components/GemTransformCooldownEligibleComponent.sol";

import {GameItems, ID as GAME_ITEMS_ID} from "../tokens/gameitems/GameItems.sol";
import {IGameCurrency} from "../tokens/IGameCurrency.sol";
import {ID as GOLD_TOKEN_STRATEGY_ID} from "../tokens/goldtoken/GoldTokenStrategy.sol";
import {ILootSystemV2, ID as LOOT_SYSTEM_ID} from "../loot/ILootSystemV2.sol";
import {ID as TRANSFORM_SYSTEM_ID} from "../transform/ITransformSystem.sol";
import {TransformSystem} from "../transform/TransformSystem.sol";
import {ICooldownSystem, ID as COOLDOWN_SYSTEM_ID} from "../cooldown/ICooldownSystem.sol";

uint256 constant GEM_TOKEN_ID = 335;

/**
 * @title GemUtilitySystem
 */
contract GemUtilitySystem is
    IGemUtilitySystem,
    GameRegistryConsumerUpgradeable
{
    /** ERRORS **/

    /// @notice Not available for gem utility
    error NotAvailable();

    /// @notice Cannot remove cooldown
    error CannotRemoveCooldown();

    /// @notice No resource cost available
    error ResourceCostNotAvailable(uint256 resourceId);

    /// @notice Error thrown when a user is not owner of the entity
    error NotOwner();

    /// @notice Invalid cost
    error InvalidCost();

    /// @notice Expected cost mismatch
    error ExpectedCostMismatch(
        uint256 expectedGemCost,
        uint256 calculatedGemCost
    );

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * @dev Start a transform, fulfill missing resources
     * Primarily used for quests and crafts and bounties
     * @param params Transform parameters
     * @param expectedGemCost Expected gem cost for the transform
     */
    function gemStartTransform(
        TransformParams calldata params,
        uint256 expectedGemCost
    ) external override whenNotPaused nonReentrant returns (uint256) {
        address caller = _getPlayerAccount(_msgSender());
        // Check if the transform is eligible for gem usage
        if (
            GemTransformEligibleComponent(
                _gameRegistry.getComponent(GEM_TRANSFORM_ELIGIBLE_COMPONENT_ID)
            ).getLayoutValue(params.transformEntity).value == false
        ) {
            revert NotAvailable();
        }
        // Handle gem exchange for the resources required
        uint256 totalEnergyInSeconds = _handleGemsForResourcesExchange(
            caller,
            params
        );

        if (totalEnergyInSeconds > 0) {
            // Convert the total energy in seconds to the gem cost, then multiply by how many times the transform is being run
            uint256 gemCost = _convertSecondsToGemCost(
                totalEnergyInSeconds,
                GemCostMultiplierComponent(
                    _gameRegistry.getComponent(GEM_COST_MULTIPLIER_COMPONENT_ID)
                ).getLayoutValue(params.transformEntity).resourceMultiplier
            ) * params.count;
            if (gemCost == 0) {
                revert InvalidCost();
            }
            // Revert if actual gem cost is greater than expected
            if (gemCost > expectedGemCost) {
                revert ExpectedCostMismatch(expectedGemCost, gemCost);
            }
            // Burn the gems from the user
            GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID)).burn(
                caller,
                GEM_TOKEN_ID,
                gemCost
            );
        }
        return
            TransformSystem(_getSystem(TRANSFORM_SYSTEM_ID))
                .startTransformWithAccount(params, caller);
    }

    /**
     * @dev Complete a transform, primarily used for bounty completion
     * @param transformInstanceEntity The transform instance entity to complete
     * @param expectedGemCost Expected gem cost for the transform
     */
    function gemCompleteTransform(
        uint256 transformInstanceEntity,
        uint256 expectedGemCost
    ) external override whenNotPaused nonReentrant {
        address caller = _getPlayerAccount(_msgSender());
        TransformInstanceComponent transformInstanceComponent = TransformInstanceComponent(
                _gameRegistry.getComponent(TRANSFORM_INSTANCE_COMPONENT_ID)
            );
        TransformInstanceComponentLayout
            memory transformInstance = transformInstanceComponent
                .getLayoutValue(transformInstanceEntity);
        if (caller != transformInstance.account) {
            revert NotOwner();
        }
        // Check if the transform is eligible for gem usage
        if (
            GemTransformEligibleComponent(
                _gameRegistry.getComponent(GEM_TRANSFORM_ELIGIBLE_COMPONENT_ID)
            ).getLayoutValue(transformInstance.transformEntity).value == false
        ) {
            revert NotAvailable();
        }
        BountyTransformConfigComponentLayout
            memory runnerConfig = BountyTransformConfigComponent(
                _gameRegistry.getComponent(BOUNTY_TRANSFORM_CONFIG_COMPONENT_ID)
            ).getLayoutValue(transformInstance.transformEntity);

        uint256 timeRemaining = transformInstance.startTime +
            runnerConfig.timeLock -
            block.timestamp;
        if (timeRemaining > 0) {
            // Handle gem cost
            uint256 gemCost = _convertSecondsToGemCost(
                timeRemaining,
                GemCostMultiplierComponent(
                    _gameRegistry.getComponent(GEM_COST_MULTIPLIER_COMPONENT_ID)
                )
                    .getLayoutValue(transformInstance.transformEntity)
                    .cooldownMultiplier
            );
            // Revert if actual gem cost is greater than expected
            if (gemCost > expectedGemCost) {
                revert ExpectedCostMismatch(expectedGemCost, gemCost);
            }
            // Burn gems
            GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID)).burn(
                caller,
                GEM_TOKEN_ID,
                gemCost
            );
            // Set to zero to indicate the cooldown has been completed
            transformInstance.startTime = 0;
            transformInstanceComponent.setLayoutValue(
                transformInstanceEntity,
                transformInstance
            );
            uint256 parentEntity = ParentComponent(
                _gameRegistry.getComponent(PARENT_COMPONENT_ID)
            ).getValue(transformInstance.transformEntity);
            ICooldownSystem(_getSystem(COOLDOWN_SYSTEM_ID)).deleteCooldown(
                EntityLibrary.addressToEntity(caller),
                parentEntity
            );
        }
        TransformSystem(_getSystem(TRANSFORM_SYSTEM_ID))
            .completeTransformWithAccount(transformInstanceEntity, caller);
    }

    /**
     * @dev Remove only the cooldown on a transform, primarily used for quest cooldowns
     * @param transformEntity The transform entity to remove the cooldown from
     * @param expectedGemCost Expected gem cost for the cooldown removal
     */
    function gemTransformCooldownRemoval(
        uint256 transformEntity,
        uint256 expectedGemCost
    ) external override whenNotPaused nonReentrant {
        address caller = _getPlayerAccount(_msgSender());
        // Check if the transform is eligible for gem coodlown usage
        if (
            GemTransformCooldownEligibleComponent(
                _gameRegistry.getComponent(
                    GEM_TRANSFORM_COOLDOWN_ELIGIBLE_COMPONENT_ID
                )
            ).getLayoutValue(transformEntity).value == false
        ) {
            revert NotAvailable();
        }
        // Handle the cooldown reduction and get the time remaining
        uint256 timeRemaining = _handleCooldownReductionOnTransform(
            transformEntity,
            caller
        );
        // Convert the total energy in seconds to the gem cost
        uint256 gemCost = _convertSecondsToGemCost(
            timeRemaining,
            GemCostMultiplierComponent(
                _gameRegistry.getComponent(GEM_COST_MULTIPLIER_COMPONENT_ID)
            ).getLayoutValue(transformEntity).cooldownMultiplier
        );
        if (gemCost == 0) {
            revert InvalidCost();
        }
        // Revert if actual gem cost is greater than expected
        if (gemCost > expectedGemCost) {
            revert ExpectedCostMismatch(expectedGemCost, gemCost);
        }
        // Burn gems
        GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID)).burn(
            caller,
            GEM_TOKEN_ID,
            gemCost
        );
    }

    /**
     * @dev Check if a cooldown reduction is needed and handle the gem cost, set the last completion time to zero
     */
    function _handleCooldownReductionOnTransform(
        uint256 transformEntity,
        address caller
    ) internal returns (uint256 timeRemaining) {
        // Get the transform account data
        TransformAccountDataComponent transformAccountDataComponent = TransformAccountDataComponent(
                _gameRegistry.getComponent(TRANSFORM_ACCOUNT_DATA_COMPONENT_ID)
            );
        uint256 accountTransformDataEntity = TransformLibrary
            ._getAccountTransformDataEntity(caller, transformEntity);

        TransformAccountDataComponentLayout
            memory accountTransformData = transformAccountDataComponent
                .getLayoutValue(accountTransformDataEntity);
        DefaultTransformRunnerConfigComponentLayout
            memory runnerConfig = DefaultTransformRunnerConfigComponent(
                _gameRegistry.getComponent(
                    DEFAULT_TRANSFORM_RUNNER_CONFIG_COMPONENT_ID
                )
            ).getLayoutValue(transformEntity);
        // Calculate time remaining
        timeRemaining =
            accountTransformData.lastCompletionTime +
            runnerConfig.cooldownSeconds -
            block.timestamp;
        // Prevent user from wasting gems if cooldown has passed
        if (timeRemaining == 0) {
            revert CannotRemoveCooldown();
        }
        // Set the last completion time to zero to indicate the cooldown has been completed
        accountTransformData.lastCompletionTime = 0;
        transformAccountDataComponent.setLayoutValue(
            accountTransformDataEntity,
            accountTransformData
        );
    }

    /**
     * @dev Check if the user has enough resources for the transform and top off if needed, handle gem cost
     */
    function _handleGemsForResourcesExchange(
        address account,
        TransformParams calldata params
    ) internal returns (uint256 resourcesInSeconds) {
        TransformInputComponentLayout
            memory transformDefInputs = TransformInputComponent(
                _gameRegistry.getComponent(TRANSFORM_INPUT_COMPONENT_ID)
            ).getLayoutValue(params.transformEntity);

        // Check inputs required against user balance
        uint256 defTokenId;
        address defTokenContract;
        uint256 defAmount;
        GemResourceCostComponent gemResourceCostComponent = GemResourceCostComponent(
                _gameRegistry.getComponent(GEM_RESOURCE_COST_COMPONENT_ID)
            );
        uint256 balance;

        for (uint8 idx; idx < transformDefInputs.inputType.length; ++idx) {
            (defTokenContract, defTokenId) = EntityLibrary.entityToToken(
                transformDefInputs.inputEntity[idx]
            );
            defAmount = transformDefInputs.amount[idx];

            if (
                ILootSystemV2.LootType(transformDefInputs.inputType[idx]) ==
                ILootSystemV2.LootType.ERC1155
            ) {
                // If no resource cost available then skip
                if (
                    !gemResourceCostComponent.has(
                        transformDefInputs.inputEntity[idx]
                    )
                ) {
                    continue;
                }
                balance = GameItems(defTokenContract).balanceOf(
                    account,
                    defTokenId
                );
                // ERC1155 balance insufficient
                if (balance < defAmount) {
                    resourcesInSeconds += _convertResourceToEnergySeconds(
                        gemResourceCostComponent,
                        transformDefInputs.inputEntity[idx],
                        defAmount - balance
                    );
                    // Mint the difference
                    GameItems(defTokenContract).mint(
                        account,
                        defTokenId,
                        defAmount - balance
                    );
                }
            } else if (
                ILootSystemV2.LootType(transformDefInputs.inputType[idx]) ==
                ILootSystemV2.LootType.ERC20
            ) {
                balance = IGameCurrency(defTokenContract).balanceOf(account);
                // ERC20 balance insufficient
                if (balance < defAmount) {
                    resourcesInSeconds += _convertResourceToEnergySeconds(
                        gemResourceCostComponent,
                        GOLD_TOKEN_STRATEGY_ID,
                        defAmount - balance
                    );
                    // Mint the difference
                    IGameCurrency(defTokenContract).mint(
                        account,
                        defAmount - balance
                    );
                }
            }
        }
    }

    /**
     * @dev Calculate the gem cost using the time remaining and the correct formula
     */
    function _calculateGemCost(
        uint256 timeRemaining,
        GemFormulaComponentLayout memory formula
    ) internal pure returns (uint256) {
        uint256 result = ((formula.numerator) *
            (timeRemaining - formula.reduction));
        // Cannot divide by zero
        result = formula.denominator == 0
            ? formula.offset
            : ((result / formula.denominator) + formula.offset);
        return result;
    }

    /**
     * @dev Takes specified resource, converts it to NRG and then converts NRG to seconds
     */
    function _convertResourceToEnergySeconds(
        GemResourceCostComponent gemResourceCostComponent,
        uint256 resourceId,
        uint256 amount
    ) internal view returns (uint256) {
        GemsResourceCostComponentLayout
            memory gemResourceCostComponentLayout = gemResourceCostComponent
                .getLayoutValue(resourceId);
        uint256 energyCost;

        if (amount < gemResourceCostComponentLayout.unitDenomination) {
            energyCost = 1;
        } else {
            energyCost =
                (amount / gemResourceCostComponentLayout.unitDenomination) *
                gemResourceCostComponentLayout.unitEnergyCost;
        }
        return energyCost * gemResourceCostComponentLayout.unitEnergyMultiplier;
    }

    /**
     * @dev Takes the final sum of seconds and converts it to the gem cost by using the correct piecewise formula
     */
    function _convertSecondsToGemCost(
        uint256 amountOfSeconds,
        uint256 multiplier
    ) internal view returns (uint256 gemCost) {
        // Use a single set of piecewise formulas assigned to this contract
        EntityListComponentLayout
            memory entityListComponentLayout = EntityListComponent(
                _gameRegistry.getComponent(ENTITY_LIST_COMPONENT_ID)
            ).getLayoutValue(ID);

        RangeComponent rangeComponent = RangeComponent(
            _gameRegistry.getComponent(RANGE_COMPONENT_ID)
        );
        RangeComponentLayout memory range;
        for (uint256 i = 0; i < entityListComponentLayout.value.length; i++) {
            range = rangeComponent.getLayoutValue(
                entityListComponentLayout.value[i]
            );
            if (
                amountOfSeconds > range.lowerBound &&
                amountOfSeconds <= range.upperBound
            ) {
                gemCost = _calculateGemCost(
                    amountOfSeconds,
                    GemFormulaComponent(
                        _gameRegistry.getComponent(GEM_FORMULA_COMPONENT_ID)
                    ).getLayoutValue(entityListComponentLayout.value[i])
                );
                break;
            }
        }
        // Apply multiplier if needed
        if (multiplier > 0) {
            gemCost = _roundUpWithMultiplier(gemCost, multiplier);
        }
    }

    /**
     * @dev Apply a multiplier to the gem cost and round up to the nearest whole number
     */
    function _roundUpWithMultiplier(
        uint currentGemCost,
        uint gemMultiplierValue
    ) internal pure returns (uint256 roundedUpResult) {
        uint256 result = (currentGemCost * gemMultiplierValue);
        roundedUpResult = result / 100 + (result % 100 == 0 ? 0 : 1);
    }
}