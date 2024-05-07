// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {MANAGER_ROLE, GAME_NFT_CONTRACT_ROLE, GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {ID as PIRATE_NFT_ID} from "../tokens/PirateNFTL2.sol";
import {ID as STARTER_PIRATE_NFT_ID} from "../tokens/starterpiratenft/StarterPirateNFT.sol";
import "../libraries/GameHelperLibrary.sol";
import {LootArrayComponentLibrary} from "../loot/LootArrayComponentLibrary.sol";

import {IEnergySystemV3, ID} from "./IEnergySystem.sol";

import {EntityLibrary} from "../core/EntityLibrary.sol";
import {IGameGlobals, ID as GAME_GLOBALS_ID} from "../gameglobals/IGameGlobals.sol";
import "../GameRegistryConsumerUpgradeable.sol";
import {EnergyComponent, Layout as EnergyComponentLayout, ID as ENERGY_COMPONENT_ID} from "../generated/components/EnergyComponent.sol";
import {EntityListComponent, Layout as EntityListComponentLayout, ID as ENTITY_LIST_COMPONENT_ID} from "../generated/components/EntityListComponent.sol";
import {EnergyPackCountComponent, ID as ENERGY_PACK_COUNT_COMPONENT_ID} from "../generated/components/EnergyPackCountComponent.sol";
import {EnergyPackComponent, Layout as EnergyPackComponentLayout, ID as ENERGY_PACK_COMPONENT_ID} from "../generated/components/EnergyPackComponent.sol";
import {ID as LOOT_ARRAY_COMPONENT_ID} from "../generated/components/LootArrayComponent.sol";

// Globals used by this contract

/// @dev Minimum energy the player must receive otherwise will be reverted
uint256 constant MIN_ENERGY_EARNABLE = 1 ether;

uint256 constant ENERGY_EARNABLE_REGEN_SECS = 3600;

// GameGlobals key for the daily energy amount per wallet
uint256 constant DAILY_ENERGY_AMOUNT_ID = uint256(
    keccak256("daily_energy_amount")
);

// Daily energy regen time value
uint256 constant DAILY_ENERGY_REGEN_SECS = 3600;

// GameGlobals key for the daily energy regen amount per time value of DAILY_ENERGY_REGEN_SECS
uint256 constant DAILY_ENERGY_REGEN_AMOUNT_ID = uint256(
    keccak256("daily_energy_regen_amount")
);

uint256 constant MAX_ENERGY_EARNABLE_ID = uint256(
    keccak256("max_energy_earnable")
);

uint256 constant ENERGY_EARNABLE_RATE = uint256(
    keccak256("energy_earnable_rate")
);

/**
 * @title EnergySystemV3
 *
 * Tracks energy accumulation and spend for a given energy
 * Note: Energy is measured in ETHER units so we can do fractional energy
 */
contract EnergySystemV3 is IEnergySystemV3, GameRegistryConsumerUpgradeable {
    /** ERRORS */

    /// @notice Emitted when a entity does not have enough energy
    error NotEnoughEnergy(uint256 expected, uint256 actual);

    /// @notice Emitted when a entity is at max energy
    error AtMaxEnergy(uint256 current, uint256 max);

    /// @notice Emitted when a entity cant earn energy
    error CannotEarnEnergy();

    /// @notice Utility not available
    error NotAvailable();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * Grants energy to the given entity without restrictions
     *
     * @param entity        Entity to grant energy to
     * @param amount        Amount of energy to grant
     */
    function grantEnergy(
        uint256 entity,
        uint256 amount
    ) external whenNotPaused nonReentrant onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _grantEnergy(entity, amount);
    }

    /**
     * Gives energy to the given entity
     *
     * @param entity        Entity to give energy to
     * @param amount        Amount of energy to give
     */
    function giveEnergy(
        uint256 entity,
        uint256 amount
    ) external whenNotPaused nonReentrant onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _giveEnergy(entity, amount);
    }

    /**
     * Gives energy to the given token
     *
     * @param tokenContract Contract to give energy to
     * @param tokenId       Token id to give energy to
     * @param amount        Amount of energy to give
     */
    function giveEnergy(
        address tokenContract,
        uint256 tokenId,
        uint256 amount
    ) external whenNotPaused nonReentrant onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _giveEnergy(
            EntityLibrary.tokenToEntity(tokenContract, tokenId),
            amount
        );
    }

    /**
     * Spends energy for the given entity
     *
     * @param entity        Entity to spend energy for
     * @param amount        Amount of energy to spend
     */
    function spendEnergy(
        uint256 entity,
        uint256 amount
    ) external whenNotPaused nonReentrant onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _spendEnergy(entity, amount);
    }

    /**
     * Spends energy for the given token
     *
     * @param tokenContract Contract to spend energy for
     * @param tokenId       Token id to spend energy for
     * @param amount        Amount of energy to spend
     */
    function spendEnergy(
        address tokenContract,
        uint256 tokenId,
        uint256 amount
    ) external whenNotPaused nonReentrant onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _spendEnergy(
            EntityLibrary.tokenToEntity(tokenContract, tokenId),
            amount
        );
    }

    /**
     * @param entity Entity to get energy data for
     *
     * @return The amount of current amount of energy for a entity
     */
    function getEnergy(
        uint256 entity
    ) external view override returns (uint256) {
        return _energyForEntity(entity);
    }

    /**
     * @param entity      Entity to get energy data for
     *
     * @return The current amount of energy earnable
     */
    function getEnergyEarnable(uint256 entity) external view returns (uint256) {
        return _energyEarnableForEntity(entity);
    }

    /**
     * Retrieves energy regen info for a given entity.
     *
     * @param entity Entity to get energy data for
     *
     * @return currentEnergy            Current amount of energy the entity has
     * @return maxEnergy                Maximum amount of energy the entity can hold at once
     * @return energyRegenPerSecond     Rate the entity accumulates new energy
     * @return lastSpendTimestamp       Last time energy was spent for this entity
     * @return lastEnergyAmount         How much energy was left after last spend    Max energy can earn value
     * @return currentEnergyEarnable    Current earnable energy
     * @return lastEnergyEarnable       How much energy could be earned after last earn
     * @return lastEarnTimestamp        Last time energy was earned for this entity
     * @return earnableRegenPerSecond    Rate the entitys earn limit restores
     * @return maxEnergyEarnable        Max energy can earn value
     */
    function getEntityData(
        uint256 entity
    )
        external
        view
        returns (
            uint256 currentEnergy,
            uint256 maxEnergy,
            uint256 energyRegenPerSecond,
            uint256 lastSpendTimestamp,
            uint256 lastEnergyAmount,
            uint256 currentEnergyEarnable,
            uint256 lastEnergyEarnable,
            uint256 lastEarnTimestamp,
            uint256 earnableRegenPerSecond,
            uint256 maxEnergyEarnable
        )
    {
        EnergyComponent energyComponent = EnergyComponent(
            _gameRegistry.getComponent(ENERGY_COMPONENT_ID)
        );
        (
            lastEnergyAmount,
            lastSpendTimestamp,
            lastEnergyEarnable,
            lastEarnTimestamp
        ) = energyComponent.getValue(entity);

        currentEnergy = _energyForEntity(entity);
        maxEnergy = _maxEnergy(entity);
        energyRegenPerSecond = _energyRegenPerSecond();
        currentEnergyEarnable = _energyEarnableForEntity(entity);
        earnableRegenPerSecond = _energyEarnableRegenPerSecond();
        maxEnergyEarnable = _maxEnergyEarnable();
    }

    /**
     * @dev Purchase energy packs, limited by the daily count
     */
    function purchaseEnergy() external whenNotPaused nonReentrant {
        address caller = _getPlayerAccount(_msgSender());
        // Energy packs
        EntityListComponentLayout
            memory entityListComponentLayout = EntityListComponent(
                _gameRegistry.getComponent(ENTITY_LIST_COMPONENT_ID)
            ).getLayoutValue(ID);
        if (entityListComponentLayout.value.length == 0) {
            revert NotAvailable();
        }
        // Form the entity for the player wallet and current day
        uint256 currentDayWalletEntity = EntityLibrary.tokenToEntity(
            caller,
            block.timestamp / 1 days
        );
        // Get the daily count for the current day
        EnergyPackCountComponent energyPackCountComponent = EnergyPackCountComponent(
                _gameRegistry.getComponent(ENERGY_PACK_COUNT_COMPONENT_ID)
            );
        uint256 dailyCount = energyPackCountComponent.getValue(
            currentDayWalletEntity
        );
        if (dailyCount >= entityListComponentLayout.value.length) {
            revert NotAvailable();
        }
        // Get the energy pack entity
        uint256 energyPackEntity = entityListComponentLayout.value[dailyCount];
        EnergyPackComponentLayout memory energyPackData = EnergyPackComponent(
            _gameRegistry.getComponent(ENERGY_PACK_COMPONENT_ID)
        ).getLayoutValue(energyPackEntity);
        if (energyPackData.energyAmount == 0) {
            revert NotAvailable();
        }
        // Handle fee
        LootArrayComponentLibrary.burnLootArray(
            _gameRegistry.getComponent(LOOT_ARRAY_COMPONENT_ID),
            caller,
            energyPackData.lootEntity
        );
        // Grant the energy needed
        _grantEnergy(
            EntityLibrary.addressToEntity(caller),
            energyPackData.energyAmount
        );
        // Increment the daily count
        energyPackCountComponent.setValue(
            currentDayWalletEntity,
            dailyCount + 1
        );
    }

    /** INTERNAL */

    function _grantEnergy(uint256 entity, uint256 amount) internal {
        // Get max energy for entity
        uint256 maxEnergy = _maxEnergy(entity);
        // Get current energy for entity
        uint256 currentEnergy = _energyForEntity(entity);
        if (maxEnergy == 0) {
            revert CannotEarnEnergy();
        }
        // User cannot exceed max energy with this grant
        if (currentEnergy + amount > maxEnergy) {
            revert CannotEarnEnergy();
        }
        EnergyComponent energyComponent = EnergyComponent(
            _gameRegistry.getComponent(ENERGY_COMPONENT_ID)
        );
        EnergyComponentLayout memory energyData = energyComponent
            .getLayoutValue(entity);
        // Update only the last energy amount to not touch drukenness
        energyData.lastEnergyAmount += amount;
        energyComponent.setLayoutValue(entity, energyData);
    }

    function _giveEnergy(uint256 entity, uint256 amount) internal {
        uint256 maxEnergy = _maxEnergy(entity);
        uint256 currentEnergyEarnable = _energyEarnableForEntity(entity);

        if (maxEnergy == 0 || currentEnergyEarnable < MIN_ENERGY_EARNABLE) {
            revert CannotEarnEnergy();
        }

        EnergyComponent energyComponent = EnergyComponent(
            _gameRegistry.getComponent(ENERGY_COMPONENT_ID)
        );
        (
            uint256 lastEnergyAmount,
            uint256 lastSpendTimestamp,
            uint256 lastEnergyEarnable,

        ) = energyComponent.getValue(entity);

        uint256 currentEnergy = _energyForEntity(entity);

        // This should be okay because of the way spend energy works, it won't let the user go over their max
        if (currentEnergy >= maxEnergy) {
            revert AtMaxEnergy(currentEnergy, maxEnergy);
        }
        uint256 amountToEarn = amount;

        if (amountToEarn > currentEnergyEarnable) {
            amountToEarn = currentEnergyEarnable;
        }

        lastEnergyAmount += amountToEarn;
        if (lastEnergyAmount > maxEnergy) {
            amountToEarn -= lastEnergyAmount - maxEnergy;
            lastEnergyAmount = maxEnergy;
        }

        lastEnergyEarnable = currentEnergyEarnable - amountToEarn;
        energyComponent.setValue(
            entity,
            lastEnergyAmount,
            lastSpendTimestamp,
            lastEnergyEarnable,
            SafeCast.toUint32(block.timestamp)
        );
    }

    function _spendEnergy(uint256 entity, uint256 amount) internal {
        uint256 currentEnergy = _energyForEntity(entity);
        if (currentEnergy < amount) {
            revert NotEnoughEnergy(amount, currentEnergy);
        }

        EnergyComponent energyComponent = EnergyComponent(
            _gameRegistry.getComponent(ENERGY_COMPONENT_ID)
        );
        (
            ,
            ,
            uint256 lastEnergyEarnable,
            uint256 lastEarnTimestamp
        ) = energyComponent.getValue(entity);

        // Store new energy info
        energyComponent.setValue(
            entity,
            currentEnergy - amount,
            SafeCast.toUint32(block.timestamp),
            lastEnergyEarnable,
            lastEarnTimestamp
        );
    }

    function _maxEnergy(uint256 entity) internal view returns (uint256) {
        // Unpack account wallet address
        address accountAddress = EntityLibrary.entityToAddress(entity);
        // If user owns zero Gen0 pirates and zero Gen1 pirates then return 0 energy
        if (
            IERC721(_getSystem(PIRATE_NFT_ID)).balanceOf(accountAddress) == 0 &&
            IERC721(_getSystem(STARTER_PIRATE_NFT_ID)).balanceOf(
                accountAddress
            ) ==
            0
        ) {
            return 0;
        }
        // Return DAILY_ENERGY_AMOUNT_ID globals value
        return
            IGameGlobals(_getSystem(GAME_GLOBALS_ID)).getUint256(
                DAILY_ENERGY_AMOUNT_ID
            );
    }

    function _energyRegenPerSecond() internal view returns (uint256) {
        IGameGlobals gameGlobals = IGameGlobals(_getSystem(GAME_GLOBALS_ID));

        // Get daily energy regeneration amount (ex: 6.25)
        uint256 dailyEnergyRegenAmount = gameGlobals.getUint256(
            DAILY_ENERGY_REGEN_AMOUNT_ID
        );

        // Return ether energy unit per hour
        return dailyEnergyRegenAmount / DAILY_ENERGY_REGEN_SECS;
    }

    function _energyForEntity(uint256 entity) internal view returns (uint256) {
        EnergyComponent energyComponent = EnergyComponent(
            _gameRegistry.getComponent(ENERGY_COMPONENT_ID)
        );
        (
            uint256 lastEnergyAmount,
            uint256 lastSpendTimestamp,
            ,

        ) = energyComponent.getValue(entity);
        uint256 maxEnergy = _maxEnergy(entity);
        // Prevent overflows by defaulting to max energy if energy has never been spent before on this entity
        // Zero max energy means no Pirate NFTs owned, so return 0
        if (lastSpendTimestamp == 0 || maxEnergy == 0) {
            return maxEnergy;
        }
        // Get the current time, subtract the last spend-time, and multiply by the energyRegPerSecond to convert it to energy, then add any energy that remained from last time
        uint256 energyAccumulated = lastEnergyAmount +
            (block.timestamp - lastSpendTimestamp) *
            _energyRegenPerSecond();
        if (energyAccumulated > maxEnergy) {
            return maxEnergy;
        } else {
            return energyAccumulated;
        }
    }

    function _energyEarnableForEntity(
        uint256 entity
    ) internal view returns (uint256) {
        EnergyComponent energyComponent = EnergyComponent(
            _gameRegistry.getComponent(ENERGY_COMPONENT_ID)
        );
        (
            ,
            ,
            uint256 lastEnergyEarnable,
            uint256 lastEarnTimestamp
        ) = energyComponent.getValue(entity);

        uint256 maxEnergyEarnable = _maxEnergyEarnable();

        // Prevent overflows by defaulting to max energy if energy has never been spent before on this entity
        if (lastEarnTimestamp == 0) {
            return maxEnergyEarnable;
        }

        uint256 energyEarnableAccumulated = lastEnergyEarnable + //0 + 0
            (block.timestamp - lastEarnTimestamp) *
            _energyEarnableRegenPerSecond();

        if (energyEarnableAccumulated > maxEnergyEarnable) {
            return maxEnergyEarnable;
        } else {
            return energyEarnableAccumulated;
        }
    }

    function _maxEnergyEarnable() internal view returns (uint256) {
        // Return DAILY_ENERGY_AMOUNT_ID globals value
        return
            IGameGlobals(_getSystem(GAME_GLOBALS_ID)).getUint256(
                MAX_ENERGY_EARNABLE_ID
            );
    }

    function _energyEarnableRegenPerSecond() internal view returns (uint256) {
        IGameGlobals gameGlobals = IGameGlobals(_getSystem(GAME_GLOBALS_ID));

        // Regen 1 ether per hour
        uint256 earnableEnergyAmount = gameGlobals.getUint256(
            ENERGY_EARNABLE_RATE
        );

        // Return ether energy unit per hour
        return earnableEnergyAmount / ENERGY_EARNABLE_REGEN_SECS;
    }
}
