// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ID as BOSS_SPAWN_ID} from "./BossSpawn.sol";
import {IMoveSystem, ID as CORE_MOVE_SYSTEM_ID} from "./IMoveSystem.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {ITokenTemplateSystem, ID as TOKEN_TEMPLATE_SYSTEM_ID} from "../tokens/ITokenTemplateSystem.sol";
import {Combatable} from "./Combatable.sol";
import {CombatStats} from "./ICombatable.sol";
import {GAME_LOGIC_CONTRACT_ROLE, ELEMENTAL_AFFINITY_TRAIT_ID, BOSS_START_TIME_TRAIT_ID, BOSS_END_TIME_TRAIT_ID} from "../Constants.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.bosscombatable"));

contract BossCombatable is Combatable {
    /** ERRORS **/

    /// @notice Invalid Boss contract
    error InvalidBossEntity();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * @dev Function returns CombatStats with calculations from CoreMoveSystem + Roll + Overloads applied to them
     * @param entityId A packed tokenId and Address
     * @param roll VRF result[0]
     * @return CombatStats An enum returning the stats that can be used for combat.
     */
    function getCombatStats(
        uint256 entityId,
        uint256 roll,
        uint256,
        uint256[] calldata
    ) external view override returns (CombatStats memory) {
        (address nftContract, uint256 nftTokenId) = EntityLibrary.entityToToken(
            entityId
        );

        // Get base CombatStats for this Boss entityId
        CombatStats memory stats = _getCombatStats(entityId);

        // Pick Boss random move (1-6 inclusive) using roll
        uint256 moveId = (roll % 6) + 1;
        int256[] memory moveMods = IMoveSystem(_getSystem(CORE_MOVE_SYSTEM_ID))
            .getCombatModifiers(moveId);

        // Calculate new combat stats taking into account move modifiers
        return
            CombatStats({
                damage: stats.damage + int64(moveMods[0]),
                evasion: stats.evasion + int64(moveMods[1]),
                speed: stats.speed + int64(moveMods[2]),
                accuracy: stats.accuracy + int64(moveMods[3]),
                // For now, we cannot modify combat stat health with moves
                // This requires game design decisions before it is implemented
                health: stats.health,
                // Pull affinity from template system
                affinity: uint64(
                    ITokenTemplateSystem(_getSystem(TOKEN_TEMPLATE_SYSTEM_ID))
                        .getTraitUint256(
                            nftContract,
                            nftTokenId,
                            ELEMENTAL_AFFINITY_TRAIT_ID
                        )
                ),
                move: uint64(moveId)
            });
    }

    /**
     * @dev Decrease the current_health trait of entityId
     * @param entityId A packed tokenId and Address
     * @param amount amount to reduce entityIds health
     * @return newHealth New current health of entityId after damage is taken.
     */
    function decreaseHealth(
        uint256 entityId,
        uint256 amount
    ) external override onlyRole(GAME_LOGIC_CONTRACT_ROLE) returns (uint256) {
        return _decreaseHealth(entityId, amount);
    }

    /**
     * @dev Check if Boss entityId can be attacked by checking if boss active/inactive, then check health
     * @param entityId A packed tokenId and Address
     * @return boolean If entityId can be attacked.
     */
    function canBeAttacked(
        uint256 entityId,
        uint256[] calldata
    ) external view override returns (bool) {
        // Unpack
        (address nftContract, uint256 nftTokenId) = EntityLibrary.entityToToken(
            entityId
        );

        if (nftContract != _getSystem(BOSS_SPAWN_ID)) {
            revert InvalidBossEntity();
        }

        ITokenTemplateSystem tokenTemplateSystem = ITokenTemplateSystem(
            _getSystem(TOKEN_TEMPLATE_SYSTEM_ID)
        );
        // Check Boss start time and end time
        if (
            block.timestamp <=
            tokenTemplateSystem.getTraitUint256(
                nftContract,
                nftTokenId,
                BOSS_START_TIME_TRAIT_ID
            ) ||
            block.timestamp >
            tokenTemplateSystem.getTraitUint256(
                nftContract,
                nftTokenId,
                BOSS_END_TIME_TRAIT_ID
            )
        ) {
            return false;
        }

        // Check Boss health == 0, if yes return false, else return true
        return !_isHealthZero(nftContract, nftTokenId);
    }

    /**
     * @dev Bosses can never initiate attack
     * @return boolean If an entity can attack
     */
    function canAttack(
        address,
        uint256,
        uint256[] calldata
    ) external pure override returns (bool) {
        return false;
    }
}
