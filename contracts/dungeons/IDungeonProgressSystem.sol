// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../GameRegistryConsumerUpgradeable.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.dungeonprogresssystem")
);

enum DungeonNodeProgressState {
    UNVISITED,
    STARTED,
    VICTORY,
    DEFEAT
}

/**
 * @title IDungeonProgressSystem
 */
interface IDungeonProgressSystem {
    /**
     * @dev Get the account progress for a dungeon.
     * @param account address of the account to get progress for
     * @param dungeon entity of the dungeon to get progress for
     * @return uint256 index of the dungeon node the account last completed
     */
    function getCurrentNode(
        address account,
        uint256 dungeon
    ) external view returns (uint256);

    /**
     * @dev Set the account progress for a dungeon.
     * @param account address of the account to set progress for
     * @param dungeon entity of the dungeon to set progress for
     * @param node index of the dungeon node to set progress to
     */
    function setCurrentNode(
        address account,
        uint256 dungeon,
        uint256 node
    ) external;

    /**
     * @dev Get the account progress for a dungeon.
     * @param account address of the account to get progress for
     * @param dungeon entity of the dungeon to get progress for
     * @param node index of the dungeon node to get progress to
     */
    function getStateForNode(
        address account,
        uint256 dungeon,
        uint256 node
    ) external view returns (DungeonNodeProgressState);

    /**
     * @dev Set the account progress for a dungeon.
     * @param account address of the account to set progress for
     * @param dungeon entity of the dungeon to set progress for
     * @param node index of the dungeon node to set progress to
     */
    function setStateForNode(
        address account,
        uint256 dungeon,
        uint256 node,
        DungeonNodeProgressState state
    ) external;

    /**
     * @dev Get the battleEntity for that account for that dungeon node.
     * @param account address of the account to get the battle for
     * @param dungeon entity of the dungeon to get the battle for
     * @param node index of the dungeon node to get the battle for
     * @return uint256 the battleEntity for that account for that node
     */
    function getBattleEntityForNode(
        address account,
        uint256 dungeon,
        uint256 node
    ) external returns (uint256);

    /**
     * @dev Set the battleEntity for that account for that dungeon node.
     * @param account address of the account to set the battle for
     * @param dungeon entity of the dungeon to set the battle for
     * @param node index of the dungeon node to set the battle for
     * @param battle the battleEntity for that account for that node
     */
    function setBattleEntityForNode(
        address account,
        uint256 dungeon,
        uint256 node,
        uint256 battle
    ) external;
}
