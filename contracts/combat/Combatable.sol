// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ACCURACY_TRAIT_ID, CURRENT_HEALTH_TRAIT_ID, DAMAGE_TRAIT_ID, EVASION_TRAIT_ID, SPEED_TRAIT_ID, GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {ITraitsProvider} from "../interfaces/ITraitsProvider.sol";
import {ITokenTemplateSystem, ID as TOKEN_TEMPLATE_SYSTEM_ID} from "../tokens/ITokenTemplateSystem.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";

import {CombatStats, ICombatable} from "./ICombatable.sol";

abstract contract Combatable is GameRegistryConsumerUpgradeable, ICombatable {
    /**
     * @dev Internal func returns base CombatStats for entityId : affinity pulled separately
     */
    function _getCombatStats(
        uint256 entityId
    ) internal view returns (CombatStats memory) {
        ITokenTemplateSystem tokenTemplateSystem = ITokenTemplateSystem(
            _getSystem(TOKEN_TEMPLATE_SYSTEM_ID)
        );
        // Extract contract address and token ID from entityId
        (address nftContract, uint256 nftTokenId) = EntityLibrary.entityToToken(
            entityId
        );

        return
            CombatStats({
                accuracy: int64(
                    tokenTemplateSystem.getTraitInt256(
                        nftContract,
                        nftTokenId,
                        ACCURACY_TRAIT_ID
                    )
                ),
                damage: int64(
                    tokenTemplateSystem.getTraitInt256(
                        nftContract,
                        nftTokenId,
                        DAMAGE_TRAIT_ID
                    )
                ),
                evasion: int64(
                    tokenTemplateSystem.getTraitInt256(
                        nftContract,
                        nftTokenId,
                        EVASION_TRAIT_ID
                    )
                ),
                health: uint64(
                    _traitsProvider().getTraitUint256(
                        nftContract,
                        nftTokenId,
                        CURRENT_HEALTH_TRAIT_ID
                    )
                ),
                speed: int64(
                    tokenTemplateSystem.getTraitInt256(
                        nftContract,
                        nftTokenId,
                        SPEED_TRAIT_ID
                    )
                ),
                affinity: 0, // Caller must set
                move: 0 // Caller may set
            });
    }

    /**
     * @dev Helper func return current health of entityId without redeclaring TraitsProvider
     */
    function getCurrentHealth(
        uint256 entityId,
        ITraitsProvider traitsProvider
    ) external view override returns (uint256) {
        // Extract contract address and token ID from entityId
        (address nftContract, uint256 nftTokenId) = EntityLibrary.entityToToken(
            entityId
        );
        return
            traitsProvider.getTraitUint256(
                nftContract,
                nftTokenId,
                CURRENT_HEALTH_TRAIT_ID
            );
    }

    /**
     * @dev Internal func decrease health of entityId
     */
    function _decreaseHealth(
        uint256 entityId,
        uint256 amount
    ) internal returns (uint256 newHealth) {
        // Extract contract address and token ID from entityId
        (address nftContract, uint256 nftTokenId) = EntityLibrary.entityToToken(
            entityId
        );

        // Get current health from TraitsProvider
        uint256 currentHealth = _traitsProvider().getTraitUint256(
            nftContract,
            nftTokenId,
            CURRENT_HEALTH_TRAIT_ID
        );
        // Calculate
        if (amount >= currentHealth) {
            newHealth = 0;
        } else {
            newHealth = currentHealth - amount;
        }
        // Update current health in TraitsProvider
        _traitsProvider().setTraitUint256(
            nftContract,
            nftTokenId,
            CURRENT_HEALTH_TRAIT_ID,
            newHealth
        );
    }

    /**
     * @dev Internal func Return true if entityId health == 0
     */
    function _isHealthZero(
        address nftContract,
        uint256 nftTokenId
    ) internal view returns (bool) {
        // Check if entityId health is zero, if yes return true, else return false
        return
            _traitsProvider().getTraitUint256(
                nftContract,
                nftTokenId,
                CURRENT_HEALTH_TRAIT_ID
            ) == 0;
    }
}
