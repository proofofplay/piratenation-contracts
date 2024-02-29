// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ACCURACY_TRAIT_ID, DAMAGE_TRAIT_ID, ELEMENTAL_AFFINITY_TRAIT_ID, EVASION_TRAIT_ID, GAME_LOGIC_CONTRACT_ROLE, HEALTH_TRAIT_ID, IS_MOB_TRAIT_ID, SPEED_TRAIT_ID} from "../Constants.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {ITraitsProvider} from "../interfaces/ITraitsProvider.sol";
import {ITokenTemplateSystem, ID as TOKEN_TEMPLATE_SYSTEM_ID} from "../tokens/ITokenTemplateSystem.sol";

import {ICombatable, CombatStats} from "./ICombatable.sol";
import {IMoveSystem, ID as CORE_MOVE_SYSTEM_ID} from "./IMoveSystem.sol";
import {ID as MOB_SPAWN_SYSTEM_ID} from "./MobSpawn.sol";

import {ShipRankComponent, ID as ShipRankComponentId, Layout as ShipRankComponentLayout} from "../generated/components/ShipRankComponent.sol";
import {IsEnemyComponent, ID as IsEnemyComponentId, Layout as IsEnemyComponentLayout} from "..//generated/components/IsEnemyComponent.sol";
import {AffinityComponent, ID as AffinityComponentId, Layout as AffinityComponentLayout} from "../generated/components/AffinityComponent.sol";
import {HealthComponent, ID as HealthComponentId, Layout as HealthComponentLayout} from "../generated/components/HealthComponent.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.mobcombatable"));

contract MobCombatable is GameRegistryConsumerUpgradeable, ICombatable {
    /** ERRORS **/

    /// @notice Invalid mob contract
    error InvalidEntity();

    /// @notice Error when function is not implemented
    error NotImplemented();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * @inheritdoc ICombatable
     */
    function getCombatStats(
        uint256 mobEntity,
        uint256 roll,
        uint256,
        uint256[] calldata
    ) external view override returns (CombatStats memory) {
        ITokenTemplateSystem tokenTemplateSystem = ITokenTemplateSystem(
            _getSystem(TOKEN_TEMPLATE_SYSTEM_ID)
        );
        (address nftContract, uint256 nftTokenId) = EntityLibrary.entityToToken(
            mobEntity
        );

        // Pick random move (1-6 inclusive) using roll
        uint256 moveId = (roll % 6) + 1;
        int256[] memory moveMods = IMoveSystem(_getSystem(CORE_MOVE_SYSTEM_ID))
            .getCombatModifiers(moveId);

        // Calculate new combat stats taking into account move modifiers
        return
            CombatStats({
                damage: int64(
                    tokenTemplateSystem.getTraitInt256(
                        nftContract,
                        nftTokenId,
                        DAMAGE_TRAIT_ID
                    ) + moveMods[0]
                ),
                evasion: int64(
                    tokenTemplateSystem.getTraitInt256(
                        nftContract,
                        nftTokenId,
                        EVASION_TRAIT_ID
                    ) + moveMods[1]
                ),
                speed: int64(
                    tokenTemplateSystem.getTraitInt256(
                        nftContract,
                        nftTokenId,
                        SPEED_TRAIT_ID
                    ) + moveMods[2]
                ),
                accuracy: int64(
                    tokenTemplateSystem.getTraitInt256(
                        nftContract,
                        nftTokenId,
                        ACCURACY_TRAIT_ID
                    ) + moveMods[3]
                ),
                // For now, we cannot modify combat stat health with moves
                // This requires game design decisions before it is implemented
                health: uint64(
                    uint256(
                        tokenTemplateSystem.getTraitInt256(
                            nftContract,
                            nftTokenId,
                            HEALTH_TRAIT_ID
                        )
                    )
                ),
                // Pull affinity from template system
                affinity: uint64(
                    tokenTemplateSystem.getTraitUint256(
                        nftContract,
                        nftTokenId,
                        ELEMENTAL_AFFINITY_TRAIT_ID
                    )
                ),
                move: uint64(moveId)
            });
    }

    /**
     * @inheritdoc ICombatable
     */
    function decreaseHealth(
        uint256,
        uint256
    )
        external
        view
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (uint256)
    {
        revert NotImplemented();
    }

    /**
     * @inheritdoc ICombatable
     */
    function canBeAttacked(
        uint256 entityId,
        uint256[] calldata
    ) external view override returns (bool) {
        IsEnemyComponent isEnemyComponent = IsEnemyComponent(
            _gameRegistry.getComponent(IsEnemyComponentId)
        );

        if (!isEnemyComponent.getValue(entityId)) {
            revert InvalidEntity();
        }

        return true;
    }

    /**
     * @inheritdoc ICombatable
     */
    function canAttack(
        address,
        uint256,
        uint256[] calldata
    ) external pure override returns (bool) {
        return false;
    }

    /**
     * @inheritdoc ICombatable
     */
    function getCurrentHealth(
        uint256 mobEntity,
        ITraitsProvider
    ) external view override returns (uint256) {
        HealthComponent healthComponent = HealthComponent(
            _gameRegistry.getComponent(HealthComponentId)
        );
        HealthComponentLayout memory health = healthComponent.getLayoutValue(
            mobEntity
        );
        return health.currentHealth;
    }
}
