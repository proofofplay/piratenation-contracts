// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {AffinitySystem, ID as AFFINITY_SYSTEM_ID} from "../affinity/AffinitySystem.sol";
import {ICooldownSystem, ID as COOLDOWN_SYSTEM_ID} from "../cooldown/ICooldownSystem.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {ID as COUNTING_SYSTEM_ID, ICountingSystem} from "../counting/ICountingSystem.sol";
import {ShipEquipment, ID as SHIP_EQUIPMENT_ID} from "../equipment/ShipEquipment.sol";
import {IGameGlobals, ID as GAME_GLOBALS_ID} from "../gameglobals/IGameGlobals.sol";
import {ITraitsProvider} from "../interfaces/ITraitsProvider.sol";
import {ITokenTemplateSystem, ID as TOKEN_TEMPLATE_SYSTEM_ID} from "../tokens/ITokenTemplateSystem.sol";

import {BattleLibrary, ValidateVersusResultParams} from "./BattleLibrary.sol";
import {ID as BOSS_COMBATABLE_ID} from "./BossCombatable.sol";
import {Battle, CoreBattleSystem} from "./CoreBattleSystem.sol";
import {CoreMoveSystem, ID as CORE_MOVE_SYSTEM_ID} from "./CoreMoveSystem.sol";
import {ICombatable, CombatStats} from "./ICombatable.sol";
import {ID as SHIP_COMBATABLE_ID} from "./ShipCombatable.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.bossbattlesystem"));

uint256 constant BOSS_BATTLE_COOLDOWN_ID = uint256(
    keccak256("boss_battle.cooldown_id")
);

uint256 constant COUNTING_TYPE_SINGLE_BOSS_DAMAGE_DEALT = uint256(
    keccak256("counting.boss_battle.damage_dealt_to_single_boss")
);

uint256 constant COUNTING_TYPE_ALL_BOSS_DAMAGE_DEALT = uint256(
    keccak256("counting.boss_battle.damage_dealt_to_all_bosses_combined")
);

// Game Globals

// Time limit for Boss battles to become available again in seconds
uint256 constant BOSS_BATTLE_COOLDOWN_TIME = uint256(
    keccak256("boss_battle.cooldown_time")
);

// Time limit for valid active Boss battles to complete in seconds
uint256 constant BOSS_BATTLE_TIME_LIMIT = uint256(
    keccak256("boss_battle.time_limit")
);

// Number of moves allowed in valid end battle submission
uint256 constant BOSS_BATTLE_MAX_MOVE_COUNT = uint256(
    keccak256("boss_battle.max_move_count")
);

/**
 * Input for calling startBattle() for Ship vs Boss
 * @param battleSeed Keccak of drand randomness value provided by client
 * @param shipEntity Entity of ShipNFT address plus token id
 * @param shipOverloads Array of ship overloads, must contain pirate captain
 * @param bossEntity Entity of BossSpawn address plus boss ID from SoT doc
 */
struct StartBattleParams {
    uint256 battleSeed;
    uint256 shipEntity;
    uint256 bossEntity;
    uint256[] shipOverloads;
}

/**
 * Input for calling endBattle() for Ship vs Boss
 * @param battleEntity Entity of battle provided from startBattle call
 * @param totalDamageTaken Damage the ship sustained
 * @param totalDamageDealt Damage the ship did to the boss
 * @param moves Set of move ids the ship made in order
 */
struct EndBattleParams {
    uint256 battleEntity;
    uint256 totalDamageTaken;
    uint256 totalDamageDealt;
    uint256[] moves;
}

/// @notice Store Combatant info for calculating for validation
struct Combatant {
    uint256 health;
    uint256 totalDamageCalculated;
    uint256 roll;
    CombatStats stats;
}

/// @notice Input param for _validateEndBattleParamsFull
struct ValidateFullParams {
    uint256 battleSeed;
    uint256 totalDamageTaken;
    uint256 totalDamageDealt;
    uint256 shipHealth;
    uint256 bossHealth;
    address account;
    uint256[] moves;
    Battle battle;
}

/// @notice Record Final Blow data
struct FinalBlow {
    uint256 shipEntity;
    address account;
}

/**
 * @title Boss Battle System
 *
 * @dev manages initialization and conclusion of battles
 */
contract BossBattleSystem is CoreBattleSystem {
    /** MEMBERS */

    /// @notice Mapping to store account address > battleEntity
    mapping(address => uint256) private _accountToBattleEntity;

    /// @notice Mapping to store bossEntity to final blow data
    mapping(uint256 => FinalBlow) public bossEntityToFinalBlow;

    /** ERRORS **/

    /// @notice Battle in progress; finish before starting new combat
    error ActiveBattleInProgress(uint256 battleEntity);

    /// @notice Ship or Boss is not valid for combat
    error InvalidEntity();

    /// @notice Ship NFT is still in cooldown
    error NftStillInCooldown();

    /// @notice Account is still in cooldown
    error AccountStillInCooldown();

    /// @notice Invalid call to end battle
    error InvalidCallToEndBattle();

    /// @notice Battle time limit expired
    error BattleExpired();

    /// @notice Invalid EndBattle params
    error InvalidEndBattleParams();

    /// @notice Invalid damage dealt value reported
    error InvalidDamageDealt();

    /// @notice Invalid damage taken value reported
    error InvalidDamageTaken();

    /** ERRORS **/

    /// @notice Emit when battle has ended
    event BossBattleResult(
        address indexed account,
        uint256 indexed shipEntity,
        uint256 indexed bossEntity,
        uint256 battleEntity,
        uint256 newShipHealth,
        uint256 newBossHealth,
        uint256 damageDealt,
        uint256 damageTaken,
        bool isFinalBlow
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
     * @dev Returns cooldown timestamp for Account
     * @return timestamp epoch time in seconds when cooldown is refreshed
     */
    function getAccountCooldown(
        address account
    ) external view returns (uint32) {
        return
            ICooldownSystem(_getSystem(COOLDOWN_SYSTEM_ID)).getCooldown(
                EntityLibrary.addressToEntity(account),
                BOSS_BATTLE_COOLDOWN_ID
            );
    }

    /**
     * @dev Returns cooldown timestamp for Ship
     * @return timestamp epoch time in seconds when cooldown is refreshed
     */
    function getShipCooldown(
        uint256 shipEntity
    ) external view returns (uint32) {
        return
            ICooldownSystem(_getSystem(COOLDOWN_SYSTEM_ID)).getCooldown(
                shipEntity,
                BOSS_BATTLE_COOLDOWN_ID
            );
    }

    /**
     * @dev Returns an active battle if one exists
     * @param battleEntity identifier for the desired battle
     * @return battle a Battle struct containing data for a battle
     * @return isActive a boolean that is true if the battle is still active
     */
    function getActiveBattle(
        uint256 battleEntity
    ) external view returns (Battle memory, bool isActive) {
        Battle memory battle = _getBattle(battleEntity);
        // BattleEntity cooldown == current time is still before battle expires
        bool beforeCooldownTime = ICooldownSystem(
            _getSystem(COOLDOWN_SYSTEM_ID)
        ).isInCooldown(battle.battleEntity, BOSS_BATTLE_COOLDOWN_ID);
        // If battle exists AND current time is still before battle expires then isActive = true
        if (battle.battleEntity != 0 && beforeCooldownTime) {
            isActive = true;
        }
        return (battle, isActive);
    }

    /**
     * @dev Returns an active battle if one exists
     * @param account address to look up an active battle by
     * @return battle a Battle struct containing data for a battle
     * @return isActive a boolean that is true if the battle is still active
     */
    function getActiveBattleByAccount(
        address account
    ) external view returns (Battle memory, bool isActive) {
        Battle memory battle = _getBattle(_accountToBattleEntity[account]);
        // BattleEntity cooldown == current time is still before battle expires
        bool beforeCooldownTime = ICooldownSystem(
            _getSystem(COOLDOWN_SYSTEM_ID)
        ).isInCooldown(battle.battleEntity, BOSS_BATTLE_COOLDOWN_ID);
        // If battle exists AND current time is still before battle expires then isActive = true
        if (battle.battleEntity != 0 && beforeCooldownTime) {
            isActive = true;
        }
        return (battle, isActive);
    }

    /**
     * @dev Create a battle if it doesnt exist for this account
     * @param params Struct of StartBattleParams inputs
     * @return battleEntity Entity of the battle
     */
    function startBattle(
        StartBattleParams calldata params
    ) external nonReentrant whenNotPaused returns (uint256) {
        address account = _getPlayerAccount(_msgSender());

        // Clear any old record
        _deleteBattle(_accountToBattleEntity[account]);

        // Get Combatable for ship and boss
        ICombatable shipCombatable = ICombatable(
            _getSystem(SHIP_COMBATABLE_ID)
        );
        ICombatable bossCombatable = ICombatable(
            _getSystem(BOSS_COMBATABLE_ID)
        );

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

        if (
            !bossCombatable.canBeAttacked(params.bossEntity, new uint256[](0))
        ) {
            revert InvalidEntity();
        }

        // Create battle and store in mapping; this kicks off a VRF request
        uint256 battleEntity = _createBattle(
            params.battleSeed,
            params.shipEntity,
            params.bossEntity,
            params.shipOverloads,
            new uint256[](0),
            shipCombatable,
            bossCombatable
        );

        // Revert if any cooldowns prevent combat from starting
        _requireValidCooldowns(account, params.shipEntity, battleEntity);

        // burn cannonballs?

        _accountToBattleEntity[account] = battleEntity;
        return battleEntity;
    }

    /**
     * @dev Resolves an active battle with validations
     * @param params Struct of EndBattleParams inputs
     */
    function endBattle(
        EndBattleParams calldata params
    ) external nonReentrant whenNotPaused {
        // Check account is executing their own battle || battle entity != 0
        address account = _getPlayerAccount(_msgSender());
        if (
            _accountToBattleEntity[account] != params.battleEntity ||
            params.battleEntity == 0
        ) {
            revert InvalidCallToEndBattle();
        }
        // Check if call to end-battle still within battle time limit
        if (
            !ICooldownSystem(_getSystem(COOLDOWN_SYSTEM_ID)).isInCooldown(
                params.battleEntity,
                BOSS_BATTLE_COOLDOWN_ID
            )
        ) {
            revert BattleExpired();
        }

        // Get Active battle
        Battle memory battle = _getBattle(params.battleEntity);

        if (
            params.moves.length >
            IGameGlobals(_getSystem(GAME_GLOBALS_ID)).getUint256(
                BOSS_BATTLE_MAX_MOVE_COUNT
            ) ||
            params.moves.length == 0
        ) {
            revert InvalidEndBattleParams();
        }

        ITraitsProvider traitsProvider = _traitsProvider();

        // Get ship starting health & boss starting health
        uint256 shipStartingHealth = battle.attackerCombatable.getCurrentHealth(
            battle.attackerEntity,
            traitsProvider
        );
        // Apply Health expertise
        shipStartingHealth = BattleLibrary.applyExpertiseHealthMod(
            traitsProvider,
            IGameGlobals(_getSystem(GAME_GLOBALS_ID)),
            shipStartingHealth,
            battle.attackerOverloads[0]
        );
        uint256 bossStartingHealth = battle.defenderCombatable.getCurrentHealth(
            battle.defenderEntity,
            traitsProvider
        );

        // Record the killing blow
        bool isFinalBlow;
        if (
            bossStartingHealth != 0 &&
            params.totalDamageDealt >= bossStartingHealth
        ) {
            isFinalBlow = true;
            bossEntityToFinalBlow[battle.defenderEntity] = FinalBlow(
                battle.attackerEntity,
                account
            );
        }

        // Simple threshold check
        if (
            !BattleLibrary.validateVersusResult(
                ValidateVersusResultParams(
                    battle.attackerEntity,
                    battle.defenderEntity,
                    battle.attackerOverloads[0],
                    params.totalDamageDealt,
                    params.moves,
                    AffinitySystem(_getSystem(AFFINITY_SYSTEM_ID)),
                    CoreMoveSystem(_getSystem(CORE_MOVE_SYSTEM_ID)),
                    ShipEquipment(_getSystem(SHIP_EQUIPMENT_ID)),
                    ITokenTemplateSystem(_getSystem(TOKEN_TEMPLATE_SYSTEM_ID)),
                    traitsProvider,
                    IGameGlobals(_getSystem(GAME_GLOBALS_ID))
                )
            )
        ) {
            revert InvalidEndBattleParams();
        }

        // Calculate full damage taken / damage dealt result, ignore if boss already dead & final attacks coming through
        // _validateEndBattleParamsFull()

        _updateBossBattleCount(
            account,
            battle.defenderEntity,
            params.totalDamageDealt
        );

        // TODO: decrease ship health when ship-repairs created
        // Emit results and set new health values of Boss & Ship
        emit BossBattleResult(
            account,
            battle.attackerEntity,
            battle.defenderEntity,
            params.battleEntity,
            shipStartingHealth,
            params.totalDamageDealt == 0
                ? bossStartingHealth
                : battle.defenderCombatable.decreaseHealth(
                    battle.defenderEntity,
                    params.totalDamageDealt
                ),
            params.totalDamageDealt,
            params.totalDamageTaken,
            isFinalBlow
        );

        // Clear battle record
        _clearBattleEntity(account);
    }

    /**
     * @dev Put a cooldown on Account, Ship, and BattleEntity (id)
     */
    function _requireValidCooldowns(
        address account,
        uint256 shipEntity,
        uint256 battleEntity
    ) internal {
        IGameGlobals gameGlobals = IGameGlobals(_getSystem(GAME_GLOBALS_ID));
        ICooldownSystem cooldown = ICooldownSystem(
            _getSystem(COOLDOWN_SYSTEM_ID)
        );

        uint32 bossBattleCooldownTime = uint32(
            gameGlobals.getUint256(BOSS_BATTLE_COOLDOWN_TIME)
        );

        // Apply cooldown on account, revert if still in cooldown
        if (
            cooldown.updateAndCheckCooldown(
                EntityLibrary.addressToEntity(account),
                BOSS_BATTLE_COOLDOWN_ID,
                bossBattleCooldownTime
            )
        ) {
            revert AccountStillInCooldown();
        }

        // Apply cooldown on nft, revert if still in cooldown
        if (
            cooldown.updateAndCheckCooldown(
                shipEntity,
                BOSS_BATTLE_COOLDOWN_ID,
                bossBattleCooldownTime
            )
        ) {
            revert NftStillInCooldown();
        }

        // Apply cooldown on battle id, fails if active
        if (
            cooldown.updateAndCheckCooldown(
                battleEntity,
                BOSS_BATTLE_COOLDOWN_ID,
                uint32(gameGlobals.getUint256(BOSS_BATTLE_TIME_LIMIT))
            )
        ) {
            revert ActiveBattleInProgress(battleEntity);
        }
    }

    function _getBattleEntity(address account) internal view returns (uint256) {
        return _accountToBattleEntity[account];
    }

    function _clearBattleEntity(address account) internal {
        _deleteBattle(_accountToBattleEntity[account]);
        delete (_accountToBattleEntity[account]);
    }

    /**
     * Uses the counting system to update the stats for the player in the counting system.
     */
    function _updateBossBattleCount(
        address account,
        uint256 bossEntity,
        uint256 totalDamageDealt
    ) internal {
        ICountingSystem countingSystem = ICountingSystem(
            _getSystem(COUNTING_SYSTEM_ID)
        );
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        countingSystem.incrementCount(
            accountEntity,
            uint256(
                keccak256(
                    abi.encode(
                        COUNTING_TYPE_SINGLE_BOSS_DAMAGE_DEALT,
                        bossEntity
                    )
                )
            ),
            totalDamageDealt
        );
        countingSystem.incrementCount(
            accountEntity,
            COUNTING_TYPE_ALL_BOSS_DAMAGE_DEALT,
            totalDamageDealt
        );
    }
}
