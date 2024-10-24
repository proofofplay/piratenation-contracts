// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";

import {TransformLibrary} from "./TransformLibrary.sol";
import {LootArrayComponentLibrary} from "../loot/LootArrayComponentLibrary.sol";

import {DefaultTransformRunnerConfigComponent, Layout as DefaultTransformRunnerConfigComponentLayout, ID as DEFAULT_TRANSFORM_RUNNER_CONFIG_COMPONENT_ID} from "../generated/components/DefaultTransformRunnerConfigComponent.sol";
import {ITransformRunnerSystem, TransformParams} from "./ITransformRunnerSystem.sol";
import {ID as LOOT_ENTITY_ARRAY_COMPONENT_ID} from "../generated/components/LootEntityArrayComponent.sol";
import {BaseTransformRunnerSystem, TransformInstanceComponentLayout} from "./BaseTransformRunnerSystem.sol";
import {StockpileCraftCountComponent, Layout as StockpileCraftCountComponentLayout, ID as STOCKPILE_CRAFT_COUNT_COMPONENT_ID} from "../generated/components/StockpileCraftCountComponent.sol";
import {StockpileTaxRunnerConfigComponent, Layout as StockpileTaxRunnerConfigComponentLayout, ID as STOCKPILE_TAX_RUNNER_CONFIG_COMPONENT_ID} from "../generated/components/StockpileTaxRunnerConfigComponent.sol";
import {ILootSystemV2, ID as LOOT_SYSTEM_ID} from "../loot/ILootSystemV2.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.stockpiletaxtransformrunnersystem")
);

contract StockpileTaxTransformRunnerSystem is BaseTransformRunnerSystem {
    /** ERRORS */

    /// @notice Tax Transform not found
    error TaxTransformNotFound();

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
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (bool needsVrf, bool skipTransformInstance)
    {
        uint256 transformEntity = params.transformEntity;
        address account = transformInstance.account;

        StockpileTaxRunnerConfigComponentLayout
            memory config = StockpileTaxRunnerConfigComponent(
                _gameRegistry.getComponent(
                    STOCKPILE_TAX_RUNNER_CONFIG_COMPONENT_ID
                )
            ).getLayoutValue(transformEntity);
        if (config.linearTaxRateLootSetEntity == 0) {
            revert TaxTransformNotFound();
        }
        // Get the current stockpile count for the user
        StockpileCraftCountComponent stockpileCraftCountComponent = StockpileCraftCountComponent(
                _gameRegistry.getComponent(STOCKPILE_CRAFT_COUNT_COMPONENT_ID)
            );
        uint256 currentStockpileCraftCount = stockpileCraftCountComponent
            .getValue(
                TransformLibrary._getAccountTransformDataEntity(
                    account,
                    transformEntity
                )
            );

        address lootEntityArrayComponentAddress = _gameRegistry.getComponent(
            LOOT_ENTITY_ARRAY_COMPONENT_ID
        );
        ILootSystemV2.Loot[]
            memory linearTaxRateLootSet = LootArrayComponentLibrary
                .convertLootEntityArrayToLoot(
                    lootEntityArrayComponentAddress,
                    config.linearTaxRateLootSetEntity
                );
        ILootSystemV2.Loot[] memory finalFeeLootSet = new ILootSystemV2.Loot[](
            linearTaxRateLootSet.length
        );
        // Calculate fee
        uint256 linearMultiplier;
        for (uint256 count = 0; count < params.count; count++) {
            linearMultiplier = currentStockpileCraftCount <
                config.flatTaxThreshold
                ? currentStockpileCraftCount
                : (config.flatTaxThreshold - 1);
            if (linearMultiplier > 0) {
                for (uint256 j = 0; j < linearTaxRateLootSet.length; j++) {
                    finalFeeLootSet[j].lootType = linearTaxRateLootSet[j]
                        .lootType;
                    finalFeeLootSet[j].lootEntity = linearTaxRateLootSet[j]
                        .lootEntity;
                    finalFeeLootSet[j].amount += (linearTaxRateLootSet[j]
                        .amount * linearMultiplier);
                }
            }

            currentStockpileCraftCount++;
        }
        if (currentStockpileCraftCount > 1) {
            // Burn fee
            LootArrayComponentLibrary.burnV2Loot(finalFeeLootSet, account);
        }

        // Update the total craft count for the user
        stockpileCraftCountComponent.setValue(
            TransformLibrary._getAccountTransformDataEntity(
                account,
                transformEntity
            ),
            currentStockpileCraftCount
        );

        return (needsVrf, skipTransformInstance);
    }

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
    function isTransformAvailable(
        address,
        TransformParams calldata
    ) external pure override returns (bool) {
        // default return turn
        return true;
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function isTransformCompleteable(
        TransformInstanceComponentLayout memory
    ) external pure override returns (bool) {
        // default return true
        return true;
    }
}
