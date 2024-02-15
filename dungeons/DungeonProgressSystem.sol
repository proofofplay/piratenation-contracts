// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./IDungeonProgressSystem.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";

/**
 * @title DungeonProgressSystem
 */
contract DungeonProgressSystem is
    IDungeonProgressSystem,
    GameRegistryConsumerUpgradeable
{
    // Account ➞ Dungeon ➞ Current Node
    mapping(address => mapping(uint256 => uint256))
        public currentNodeForAccount;

    // Account ➞ Dungeon ➞ Node ➞ Dungeon Node State
    mapping(address => mapping(uint256 => mapping(uint256 => DungeonNodeProgressState)))
        public nodeStateForAccount;

    // Account ➞ Dungeon ➞ Node ➞ Battle Entity
    mapping(address => mapping(uint256 => mapping(uint256 => uint256)))
        public battleForNodeForAccount;

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * @inheritdoc IDungeonProgressSystem
     */
    function getCurrentNode(
        address account,
        uint256 dungeon
    ) external view returns (uint256) {
        return currentNodeForAccount[account][dungeon];
    }

    /**
     * @inheritdoc IDungeonProgressSystem
     */
    function setCurrentNode(
        address account,
        uint256 dungeon,
        uint256 node
    ) external onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        currentNodeForAccount[account][dungeon] = node;
    }

    /**
     * @inheritdoc IDungeonProgressSystem
     */
    function getStateForNode(
        address account,
        uint256 dungeon,
        uint256 node
    ) external view returns (DungeonNodeProgressState) {
        return nodeStateForAccount[account][dungeon][node];
    }

    /**
     * @inheritdoc IDungeonProgressSystem
     */
    function setStateForNode(
        address account,
        uint256 dungeon,
        uint256 node,
        DungeonNodeProgressState state
    ) external onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        nodeStateForAccount[account][dungeon][node] = state;
    }

    /**
     * @inheritdoc IDungeonProgressSystem
     */
    function getBattleEntityForNode(
        address account,
        uint256 dungeon,
        uint256 node
    ) external view returns (uint256) {
        return battleForNodeForAccount[account][dungeon][node];
    }

    /**
     * @inheritdoc IDungeonProgressSystem
     */
    function setBattleEntityForNode(
        address account,
        uint256 dungeon,
        uint256 node,
        uint256 battle
    ) external onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        battleForNodeForAccount[account][dungeon][node] = battle;
    }
}
