// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Battle, CoreBattleSystem} from "../combat/CoreBattleSystem.sol";
import {ICombatable} from "../combat/ICombatable.sol";
import {ID as SHIP_COMBATABLE_ID} from "../combat/ShipCombatable.sol";
import {ID as MOB_COMBATABLE_ID} from "../combat/MobCombatable.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {Uint256Component, ID as UINT256_COMPONENT_ID} from "../generated/components/Uint256Component.sol";
import {ICooldownSystem, ID as COOLDOWN_SYSTEM_ID} from "../cooldown/ICooldownSystem.sol";
import {ShipEquipment, ID as SHIP_EQUIPMENT_ID} from "../equipment/ShipEquipment.sol";
import {EndBattleParams, IDungeonBattleSystemV2, ID} from "./IDungeonBattleSystemV2.sol";
import {StartDungeonBattleParams, DungeonTrigger, DungeonNode} from "./IDungeonSystemV3.sol";

import "../GameRegistryConsumerUpgradeable.sol";

uint256 constant DUNGEON_BATTLE_COOLDOWN_ID = uint256(
    keccak256("dungeon_battle.cooldown_id")
);

// Time limit for valid active battles to complete in seconds
uint256 constant DUNGEON_BATTLE_TIME_LIMIT = uint256(
    keccak256("game.piratenation.global.dungeon_battle.time_limit")
);

/**
 * @title DungeonBattleSystemV2
 */
contract DungeonBattleSystemV2 is CoreBattleSystem, IDungeonBattleSystemV2 {
    /** MEMBERS */

    /// @notice Mapping to store account address > battleEntity
    mapping(address => uint256) private _accountToBattleEntity;

    /** ERRORS **/

    /// @notice Battle time limit expired
    error BattleExpired();

    /// @notice Invalid call to end battle
    error InvalidCallToEndBattle();

    /// @notice Ship or Mob is not valid for combat
    error InvalidEntity();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * @inheritdoc IDungeonBattleSystemV2
     */
    function startBattle(
        address account,
        StartDungeonBattleParams calldata params,
        DungeonNode calldata node
    ) external override onlyRole(GAME_LOGIC_CONTRACT_ROLE) returns (uint256) {
        ICooldownSystem cooldown = ICooldownSystem(
            _getSystem(COOLDOWN_SYSTEM_ID)
        );

        // Clear any old record
        _clearBattle(account, cooldown);

        // Get Combatable for ship and mob
        ICombatable shipCombatable = ICombatable(
            _getSystem(SHIP_COMBATABLE_ID)
        );
        ICombatable mobCombatable = ICombatable(_getSystem(MOB_COMBATABLE_ID));

        // Check if combatants are capable of combat
        if (
            !shipCombatable.canAttack(
                account,
                params.shipEntity,
                params.shipOverloads
            )
        ) {
            revert InvalidEntity();
        }

        for (uint i = 0; i < node.enemies.length; i++) {
            if (
                node.enemies[i] != 0 &&
                !mobCombatable.canBeAttacked(node.enemies[i], new uint256[](0))
            ) {
                revert InvalidEntity();
            }
        }

        // Create battle and store in mapping
        uint256 battleEntity = _createBattle(
            params.battleSeed,
            params.shipEntity,
            node.enemies[0],
            params.shipOverloads,
            new uint256[](0),
            shipCombatable,
            mobCombatable
        );

        // Apply cooldown on battle entity
        cooldown.updateAndCheckCooldown(
            battleEntity,
            DUNGEON_BATTLE_COOLDOWN_ID,
            uint32(
                Uint256Component(
                    _gameRegistry.getComponent(UINT256_COMPONENT_ID)
                ).getValue(DUNGEON_BATTLE_TIME_LIMIT)
            )
        );

        // We don't need to restrict number of battles started here,
        // that should be handled in the calling contract
        _accountToBattleEntity[account] = battleEntity;
        return battleEntity;
    }

    /**
     * @inheritdoc IDungeonBattleSystemV2
     */
    function endBattle(
        EndBattleParams calldata params
    ) external override onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        // Battle memory battle = _getBattle(params.battleEntity);

        // Make battle validation checks
        _validateEndBattle(params);

        // TODO: Record a battle result
        // Clear battle record
        _clearBattle(
            params.account,
            ICooldownSystem(_getSystem(COOLDOWN_SYSTEM_ID))
        );
    }

    /** INTERNAL **/

    function _clearBattle(address account, ICooldownSystem cooldown) internal {
        uint256 battleEntity = _accountToBattleEntity[account];
        if (battleEntity == 0) {
            return;
        }

        // Delete battle specific cooldowns
        cooldown.deleteCooldown(battleEntity, DUNGEON_BATTLE_COOLDOWN_ID);

        // Delete battle entity from mapping
        _deleteBattle(battleEntity);
        delete (_accountToBattleEntity[account]);
    }

    function _validateEndBattle(EndBattleParams calldata params) internal view {
        // Check account is executing their own battle || battle entity != 0
        if (
            _accountToBattleEntity[params.account] != params.battleEntity ||
            params.battleEntity == 0
        ) {
            revert InvalidCallToEndBattle();
        }

        // Check if call to end-battle still within battle time limit
        if (
            !ICooldownSystem(_getSystem(COOLDOWN_SYSTEM_ID)).isInCooldown(
                params.battleEntity,
                DUNGEON_BATTLE_COOLDOWN_ID
            )
        ) {
            revert BattleExpired();
        }
    }
}
