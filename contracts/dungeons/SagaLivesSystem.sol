// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.26;

import "../GameRegistryConsumerUpgradeable.sol";

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {MANAGER_ROLE, GAME_NFT_CONTRACT_ROLE, GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {ID as PIRATE_NFT_ID} from "../tokens/PirateNFTL2.sol";
import {ID as STARTER_PIRATE_NFT_ID} from "../tokens/starterpiratenft/StarterPirateNFT.sol";

import {EntityLibrary} from "../core/EntityLibrary.sol";

import {Uint256Component, ID as Uint256ComponentId} from "../generated/components/Uint256Component.sol";
import {SagaLivesComponent, Layout as SagaLivesComponentLayout, ID as SAGA_LIVES_COMPONENT_ID} from "../generated/components/SagaLivesComponent.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.sagalivessystem"));

// Globals used by the system

// Daily lives amount value global
uint256 constant DAILY_LIVES_AMOUNT_ID = uint256(
    keccak256("game.piratenation.global.daily_lives_amount")
);

// Daily lives regen amount value global
uint256 constant DAILY_LIVES_REGEN_AMOUNT_ID = uint256(
    keccak256("game.piratenation.global.daily_lives_regen_amount")
);

// Daily lives regen seconds value global
uint256 constant DAILY_LIVES_REGEN_SECS_ID = uint256(
    keccak256("game.piratenation.global.daily_lives_regen_seconds")
);

/** ERRORS */

/// @notice Error when no pirate NFT is found
error NoPirateNFT();

/// @notice Error when a entity does not have enough lives
error NotEnoughLives(uint256 expected, uint256 actual);

/// @notice Invalid input parameters
error InvalidInputParameters();

/**
 * @title SagaLivesSystem
 * Tracks and regenerates the saga lives for a given entity
 */
contract SagaLivesSystem is GameRegistryConsumerUpgradeable {
    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * Spends lives for a given entity
     *
     * @param entity Entity to spend lives for
     * @param amount Amount of lives to spend
     */
    function spendLives(
        uint256 entity,
        uint256 amount
    ) external whenNotPaused nonReentrant onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        if (entity == 0 || amount == 0) {
            revert InvalidInputParameters();
        }
        _spendLives(entity, amount);
    }

    /**
     * @param entity Entity to get lives for
     *
     * @return The amount of lives for the given entity
     */
    function getLives(uint256 entity) external view returns (uint256) {
        return _livesForEntity(entity);
    }

    /** INTERNAL */

    /**
     * Internal function spends lives for a given entity and updates the entity's sagaLivesComponent
     */
    function _spendLives(uint256 entity, uint256 amount) internal {
        uint256 currentLives = _livesForEntity(entity);
        if (currentLives < amount) {
            revert NotEnoughLives(amount, currentLives);
        }
        SagaLivesComponent sagaLivesComponent = SagaLivesComponent(
            _gameRegistry.getComponent(SAGA_LIVES_COMPONENT_ID)
        );
        // Store new saga lives info
        sagaLivesComponent.setValue(
            entity,
            currentLives - amount,
            SafeCast.toUint32(block.timestamp)
        );
    }

    /**
     * Internal function checks if the entity has a pirate NFT and returns the max lives possible
     */
    function _maxLives(uint256 entity) internal view returns (uint256) {
        address accountAddress = EntityLibrary.entityToAddress(entity);

        // If user owns zero Gen0 pirates and zero Gen1 pirates then revert
        if (
            IERC721(_getSystem(PIRATE_NFT_ID)).balanceOf(accountAddress) == 0 &&
            IERC721(_getSystem(STARTER_PIRATE_NFT_ID)).balanceOf(
                accountAddress
            ) ==
            0
        ) {
            revert NoPirateNFT();
        }
        return
            Uint256Component(_gameRegistry.getComponent(Uint256ComponentId))
                .getValue(DAILY_LIVES_AMOUNT_ID);
    }

    /**
     * Internal function returns the regeneration rate of lives per time span
     */
    function _lifeRegenPerTimeSpan() internal view returns (uint256) {
        // Get daily life regeneration amount per time span
        uint256 dailyLifeRegenAmount = Uint256Component(
            _gameRegistry.getComponent(Uint256ComponentId)
        ).getValue(DAILY_LIVES_REGEN_AMOUNT_ID);
        return dailyLifeRegenAmount;
    }

    /**
     * Internal function calculates and returns the amount of lives for a given entity
     */
    function _livesForEntity(uint256 entity) internal view returns (uint256) {
        SagaLivesComponentLayout memory sagaLivesLayout = SagaLivesComponent(
            _gameRegistry.getComponent(SAGA_LIVES_COMPONENT_ID)
        ).getLayoutValue(entity);
        uint256 maxLives = _maxLives(entity);
        // Default to max lives if entity has no saga lives history
        if (sagaLivesLayout.lastSpendTimestamp == 0 || maxLives == 0) {
            return maxLives;
        }
        uint256 regenSeconds = Uint256Component(
            _gameRegistry.getComponent(Uint256ComponentId)
        ).getValue(DAILY_LIVES_REGEN_SECS_ID);
        // Calculate amount of lives accumulated since last spend
        uint256 livesAccumulated = ((block.timestamp -
            sagaLivesLayout.lastSpendTimestamp) / regenSeconds) *
            _lifeRegenPerTimeSpan() +
            sagaLivesLayout.lastLifeAmount;
        if (livesAccumulated > maxLives) {
            return maxLives;
        } else {
            return livesAccumulated;
        }
    }
}
