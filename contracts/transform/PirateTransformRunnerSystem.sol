// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import "../libraries/RandomLibrary.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";

import {GAME_LOGIC_CONTRACT_ROLE, GAME_NFT_CONTRACT_ROLE} from "../Constants.sol";

import {ILevelSystem, ID as LEVEL_SYSTEM_ID} from "../level/ILevelSystem.sol";
import {IEnergySystemV3, ID as ENERGY_SYSTEM_ID} from "../energy/IEnergySystem.sol";
import {ITransformRunnerSystem, TransformParams} from "./ITransformRunnerSystem.sol";
import {PirateTransformRunnerConfigComponent, Layout as PirateTransformRunnerConfigComponentLayout, ID as PIRATE_QUEST_RUNNER_CONFIG_COMPONENT_ID} from "../generated/components/PirateTransformRunnerConfigComponent.sol";
import {LootEntityArrayComponent, Layout as LootEntityArrayComponentLayout} from "../generated/components/LootEntityArrayComponent.sol";
import {BaseTransformRunnerSystem, TransformInputComponentLayout, TransformInstanceComponentLayout} from "./BaseTransformRunnerSystem.sol";
import {IsPirateComponent, ID as IS_PIRATE_COMPONENT_ID} from "../generated/components/IsPirateComponent.sol";
import {GenerationComponent, ID as GENERATION_COMPONENT_ID} from "../generated/components/GenerationComponent.sol";
import {LevelComponent, ID as LEVEL_COMPONENT_ID} from "../generated/components/LevelComponent.sol";

import "../GameRegistryConsumerUpgradeable.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.piratetransformrunnersystem")
);

contract PirateTransformRunnerSystem is BaseTransformRunnerSystem {
    /** EVENTS */

    // TODO: Temporary, remove when leaderboards are implemented
    /// @notice Emitted when a quest has been completed
    event PirateTransformCompleted(
        address account,
        uint256 transformEntity,
        uint16 startedCount,
        uint16 successCount,
        address nftTokenContract,
        uint256 nftTokenId
    );

    /** ERRORS */

    /// @notice Error when first input is not a pirate NFT
    error FirstInputMustBePirateNFT();

    /// @notice Error when pirate generation is invalid
    error InvalidPirateLevel(uint32 min, uint32 max, uint32 actual);

    /// @notice Error when pirate generation is invalid
    error InvalidPirateGeneration(uint32 min, uint32 max, uint32 actual);

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

        PirateTransformRunnerConfigComponentLayout
            memory runnerConfig = _getPirateTransformRunnerConfig(
                transformEntity
            );

        // Spend energy if needed
        if (runnerConfig.energyRequired > 0) {
            uint256 totalEnergyRequired = runnerConfig.energyRequired *
                params.count;

            // Subtract energy from user wallet entity
            IEnergySystemV3(_getSystem(ENERGY_SYSTEM_ID)).spendEnergy(
                EntityLibrary.addressToEntity(transformInstance.account),
                totalEnergyRequired
            );
        }

        // Check pirate level and generation
        (address tokenContract, uint256 tokenId) = EntityLibrary.entityToToken(
            params.inputs[0].lootEntity
        );
        _checkPirateLevelAndGeneration(tokenContract, tokenId, runnerConfig);

        // Set needsVRF flag
        needsVrf = _needsVrf(runnerConfig);
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
        numSuccess = 0;

        // Grant XP on success
        PirateTransformRunnerConfigComponentLayout
            memory runnerConfig = _getPirateTransformRunnerConfig(
                transformInstance.transformEntity
            );

        if (transformInstance.needsVrf) {
            (numSuccess, nextRandomWord) = RandomLibrary.weightedCoinFlipBatch(
                randomWord,
                runnerConfig.baseSuccessProbability,
                transformInstance.count
            );
        } else {
            numSuccess = transformInstance.count;
        }

        if (numSuccess > 0 && runnerConfig.successXp > 0) {
            LootEntityArrayComponentLayout
                memory inputs = _getTransformInstanceInputs(
                    transformInstanceEntity
                );

            ILevelSystem levelSystem = ILevelSystem(
                _getSystem(LEVEL_SYSTEM_ID)
            );

            (address tokenContract, uint256 tokenId) = EntityLibrary
                .entityToToken(inputs.lootEntity[0]);
            levelSystem.grantXP(
                tokenContract,
                tokenId,
                runnerConfig.successXp * numSuccess
            );
        }
    }

    function onTransformComplete(
        TransformInstanceComponentLayout memory transformInstance,
        uint256 transformInstanceEntity,
        uint256 randomWord
    ) external override returns (uint256 nextRandomWord) {
        return randomWord;
    }

    /** INTERNAL */

    /**
     * @dev Check pirate level and generation, reverts if any checks fail
     *
     * @param tokenContract Address of the token contract
     * @param tokenId ID of the token
     * @param config PirateTransformRunnerConfigComponentLayout
     */
    function _checkPirateLevelAndGeneration(
        address tokenContract,
        uint256 tokenId,
        PirateTransformRunnerConfigComponentLayout memory config
    ) internal view {
        // Make sure input zero is a pirate NFT
        if (
            IsPirateComponent(
                _gameRegistry.getComponent(IS_PIRATE_COMPONENT_ID)
            ).getValue(EntityLibrary.tokenToEntity(tokenContract, tokenId)) ==
            false
        ) {
            revert FirstInputMustBePirateNFT();
        }

        uint256 entityId = EntityLibrary.tokenToEntity(tokenContract, tokenId);

        // Get pirate level
        uint32 pirateLevel = uint32(
            LevelComponent(_gameRegistry.getComponent(LEVEL_COMPONENT_ID))
                .getValue(entityId)
        );

        // Get pirate generation
        uint32 pirateGeneration = uint32(
            GenerationComponent(
                _gameRegistry.getComponent(GENERATION_COMPONENT_ID)
            ).getValue(entityId)
        );

        // Check pirate level
        if (
            pirateLevel < config.minPirateLevel ||
            pirateLevel > config.maxPirateLevel
        ) {
            revert InvalidPirateLevel(
                config.minPirateLevel,
                config.maxPirateLevel,
                pirateLevel
            );
        }

        // Check pirate generation
        if (
            pirateGeneration < config.minPirateGeneration ||
            pirateGeneration > config.maxPirateGeneration
        ) {
            revert InvalidPirateGeneration(
                config.minPirateGeneration,
                config.maxPirateGeneration,
                pirateGeneration
            );
        }
    }

    function _getPirateTransformRunnerConfig(
        uint256 transformEntity
    )
        internal
        view
        returns (PirateTransformRunnerConfigComponentLayout memory)
    {
        PirateTransformRunnerConfigComponent configComponent = PirateTransformRunnerConfigComponent(
                _gameRegistry.getComponent(
                    PIRATE_QUEST_RUNNER_CONFIG_COMPONENT_ID
                )
            );
        PirateTransformRunnerConfigComponentLayout
            memory runnerConfig = configComponent.getLayoutValue(
                transformEntity
            );
        return runnerConfig;
    }

    /**
     * Checks if the transform requires VRF
     *
     * @param runnerConfig config for the transform runner
     *
     * @return bool whether or not the transform requires VRF
     */
    function _needsVrf(
        PirateTransformRunnerConfigComponentLayout memory runnerConfig
    ) internal pure returns (bool) {
        return (runnerConfig.baseSuccessProbability < PERCENTAGE_RANGE &&
            runnerConfig.baseSuccessProbability != 0);
    }
}
