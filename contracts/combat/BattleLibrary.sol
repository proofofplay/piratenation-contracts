// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {AFFINITY_PRECISION_FACTOR, AffinitySystem} from "../affinity/AffinitySystem.sol";
import {CoreMoveSystem} from "../combat/CoreMoveSystem.sol";
import {DAMAGE_TRAIT_ID, ELEMENTAL_AFFINITY_TRAIT_ID, LEVEL_TRAIT_ID, EXPERTISE_TRAIT_ID, EXPERTISE_DAMAGE_ID, EXPERTISE_EVASION_ID, EXPERTISE_SPEED_ID, EXPERTISE_ACCURACY_ID, EXPERTISE_HEALTH_ID} from "../Constants.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {IEquippable} from "../equipment/IEquippable.sol";
import {ITokenTemplateSystem} from "../tokens/ITokenTemplateSystem.sol";
import {ITraitsProvider} from "../interfaces/ITraitsProvider.sol";
import {CombatStats} from "./Combatable.sol";
import {IGameGlobals} from "../gameglobals/IGameGlobals.sol"; // DELETE?

/**
 * @dev Parameters for the validateVersusBattleResult function
 * @param attackerEntity Entity of the attacker (ship NFT)
 * @param defenderEntity Entity of the defender (boss or mob template)
 * @param attackerOverload Entity of the attacker overload (pirate NFT)
 * @param totalDamageDealt Total damage dealt by the attacker
 * @param moves Moves used by the attacker
 * @param affinitySystem Affinity system
 * @param moveSystem Move system
 * @param tokenTemplateSystem TokenTemplate system
 */
struct ValidateVersusResultParams {
    uint256 attackerEntity;
    uint256 defenderEntity;
    uint256 attackerOverload;
    uint256 totalDamageDealt;
    uint256[] moves;
    AffinitySystem affinitySystem;
    CoreMoveSystem moveSystem;
    IEquippable attackerEquippable;
    ITokenTemplateSystem tokenTemplateSystem;
    ITraitsProvider traitsProvider;
    IGameGlobals gameGlobals;
}

enum ExpertiseTypes {
    UNDEFINED,
    DAMAGE,
    EVASION,
    SPEED,
    ACCURACY,
    HEALTH
}

/**
 * @title Battle helpers Library
 */
library BattleLibrary {
    /**
     * @dev Perform simple combat validation
     */
    function validateVersusResult(
        ValidateVersusResultParams memory params
    ) internal view returns (bool) {
        // Get defender affinity from TokenTemplate system
        (address tokenContract, uint256 tokenId) = EntityLibrary.entityToToken(
            params.defenderEntity
        );
        uint256 defenderAffinity = params.tokenTemplateSystem.getTraitUint256(
            tokenContract,
            tokenId,
            ELEMENTAL_AFFINITY_TRAIT_ID
        );

        // Get pirate affinity from TraitsProvider
        (tokenContract, tokenId) = EntityLibrary.entityToToken(
            params.attackerOverload
        );

        // Get affinity for attacker overload vs defender, cast to int256
        int256 attackerAffinityModifier = SafeCast.toInt256(
            params.affinitySystem.getDamageModifier(
                params.traitsProvider.getTraitUint256(
                    tokenContract,
                    tokenId,
                    ELEMENTAL_AFFINITY_TRAIT_ID
                ),
                defenderAffinity
            )
        );

        // Get attacker base damage from TokenTemplate
        (tokenContract, tokenId) = EntityLibrary.entityToToken(
            params.attackerEntity
        );
        int256 attackerBaseDamage = params.tokenTemplateSystem.getTraitInt256(
            tokenContract,
            tokenId,
            DAMAGE_TRAIT_ID
        );
        // Apply Damage mod from expertise
        attackerBaseDamage = applyExpertiseDamageMod(
            params.traitsProvider,
            params.gameGlobals,
            attackerBaseDamage,
            params.attackerOverload
        );

        // Retrieve combat stat modifiers from equipment and move system
        int256[] memory equipmentMods = params
            .attackerEquippable
            .getCombatModifiers(params.attackerEntity);

        // Calculate damage for each move done
        int256[] memory moveMods;
        int256 totalDamageCalculated;
        for (uint i = 0; i < params.moves.length; ++i) {
            moveMods = params.moveSystem.getCombatModifiers(params.moves[i]);
            totalDamageCalculated +=
                ((attackerBaseDamage + equipmentMods[0] + moveMods[0]) *
                    attackerAffinityModifier) /
                AFFINITY_PRECISION_FACTOR;
        }

        // Reported attacker damage cannot exceed total calculated damage
        if (params.totalDamageDealt > uint256(totalDamageCalculated)) {
            return false;
        }

        return true;
    }

    /**
     * @dev Take in base damage and apply expertise damage modifier if applicable
     * @param traitsProvider Traits provider
     * @param gameGlobals Game globals
     * @param baseDamage Base damage
     * @param entity Pirate NFT entity
     */
    function applyExpertiseDamageMod(
        ITraitsProvider traitsProvider,
        IGameGlobals gameGlobals,
        int256 baseDamage,
        uint256 entity
    ) internal view returns (int256) {
        // Get Pirate NFT contract and token ID
        (address pirateContract, uint256 pirateTokenId) = EntityLibrary
            .entityToToken(entity);

        // If Pirate has Damage expertise apply modifier, else return base damage
        if (
            traitsProvider.getTraitUint256(
                pirateContract,
                pirateTokenId,
                EXPERTISE_TRAIT_ID
            ) == uint256(ExpertiseTypes.DAMAGE)
        ) {
            // Get damage mod and multiply by Pirate level
            int256 damageMod = gameGlobals.getInt256(EXPERTISE_DAMAGE_ID);
            baseDamage +=
                damageMod *
                SafeCast.toInt256(
                    traitsProvider.getTraitUint256(
                        pirateContract,
                        pirateTokenId,
                        LEVEL_TRAIT_ID
                    )
                );
        }
        return baseDamage;
    }

    /**
     * @dev Take in base health and apply expertise health modifier if applicable
     * @param traitsProvider Traits provider
     * @param gameGlobals Game globals
     * @param baseHealth Base health
     * @param entity Pirate NFT entity
     */
    function applyExpertiseHealthMod(
        ITraitsProvider traitsProvider,
        IGameGlobals gameGlobals,
        uint256 baseHealth,
        uint256 entity
    ) internal view returns (uint256) {
        // Get Pirate NFT contract and token ID
        (address pirateContract, uint256 pirateTokenId) = EntityLibrary
            .entityToToken(entity);

        // If Pirate has Health expertise apply modifier, else return base health
        if (
            traitsProvider.getTraitUint256(
                pirateContract,
                pirateTokenId,
                EXPERTISE_TRAIT_ID
            ) == uint256(ExpertiseTypes.HEALTH)
        ) {
            // Get health mod and multiply by Pirate level
            int256 healthMod = gameGlobals.getInt256(EXPERTISE_HEALTH_ID);
            baseHealth +=
                SafeCast.toUint256(healthMod) *
                traitsProvider.getTraitUint256(
                    pirateContract,
                    pirateTokenId,
                    LEVEL_TRAIT_ID
                );
        }
        return baseHealth;
    }

    /**
     *
     * @param traitsProvider Traits provider
     * @param gameGlobals Game globals
     * @param stats Combat stats
     * @param pirateEntity Pirate entity
     */
    function applyExpertiseToCombatStats(
        ITraitsProvider traitsProvider,
        IGameGlobals gameGlobals,
        CombatStats memory stats,
        uint256 pirateEntity
    ) internal view returns (CombatStats memory) {
        // Get Pirate NFT contract and token ID
        (address pirateContract, uint256 pirateTokenId) = EntityLibrary
            .entityToToken(pirateEntity);

        // Get Pirate expertise
        uint256 pirateExpertise = traitsProvider.getTraitUint256(
            pirateContract,
            pirateTokenId,
            EXPERTISE_TRAIT_ID
        );

        // Get Pirate level
        int256 pirateLevel = SafeCast.toInt256(
            traitsProvider.getTraitUint256(
                pirateContract,
                pirateTokenId,
                LEVEL_TRAIT_ID
            )
        );

        // Temporarily cast to int256 for high precision calculations
        int256 newValue;
        if (pirateExpertise == uint256(ExpertiseTypes.DAMAGE)) {
            // Apply Damage mod from expertise
            newValue = gameGlobals.getInt256(EXPERTISE_DAMAGE_ID);
            stats.damage += SafeCast.toInt64(newValue * pirateLevel);
        } else if (pirateExpertise == uint256(ExpertiseTypes.EVASION)) {
            // Apply Evasion mod from expertise
            newValue = gameGlobals.getInt256(EXPERTISE_EVASION_ID);
            stats.evasion += SafeCast.toInt64(newValue * pirateLevel);
        } else if (pirateExpertise == uint256(ExpertiseTypes.SPEED)) {
            // Apply Speed mod from expertise
            newValue = gameGlobals.getInt256(EXPERTISE_SPEED_ID);
            stats.speed += SafeCast.toInt64(newValue * pirateLevel);
        } else if (pirateExpertise == uint256(ExpertiseTypes.ACCURACY)) {
            // Apply Accuracy mod from expertise
            newValue = gameGlobals.getInt256(EXPERTISE_ACCURACY_ID);
            stats.accuracy += SafeCast.toInt64(newValue * pirateLevel);
        }
        // Health is handled separately

        return stats;
    }
}
