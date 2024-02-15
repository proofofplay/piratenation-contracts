// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.battleevents"));

enum VersusResultType {
    UNDEFINED,
    ATTACKER_WIN,
    DEFENDER_WIN,
    DRAW
}

/**
 * @title BattleEvents
 *
 * @dev Contract for emitting common battle events.
 */
contract BattleEvents is GameRegistryConsumerUpgradeable {
    /** EVENTS */

    /// @notice Emitted when a battle is ended between two opponents
    event VersusBattleResult(
        address indexed account,
        uint256 indexed attackerEntity,
        uint256 indexed defenderEntity,
        uint256 battleEntity,
        uint256 newAttackerHealth,
        uint256 newDefenderHealth,
        uint256 totalAttackerDamage,
        uint256 totalDefenderDamage,
        VersusResultType resultType
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
     * @dev Function to emit an event when a battle is ended between two opponents
     * @param account the address of the account that ended the battle
     * @param attackerEntity A packed address and token ID for the attacker
     * @param defenderEntity A packed address and token ID for the defender
     */
    function emitVersusBattleResult(
        address account,
        uint256 attackerEntity,
        uint256 defenderEntity,
        uint256 battleEntity,
        uint256 newAttackerHealth,
        uint256 newDefenderHealth,
        uint256 totalAttackerDamage,
        uint256 totalDefenderDamage,
        VersusResultType resultType
    ) external onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        emit VersusBattleResult(
            account,
            attackerEntity,
            defenderEntity,
            battleEntity,
            newAttackerHealth,
            newDefenderHealth,
            totalAttackerDamage,
            totalDefenderDamage,
            resultType
        );
    }
}
