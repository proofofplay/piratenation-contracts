// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../GameRegistryConsumerUpgradeable.sol";

import {DungeonNodeProgressState} from "./IDungeonProgressSystem.sol";
import {ILootSystemV2} from "../loot/ILootSystemV2.sol";

struct StartAndEndDungeonBattleParams {
    uint256 battleSeed;
    uint256 scheduledStart;
    uint256 mapEntity;
    uint256 encounterEntity;
    uint256 shipEntity;
    uint256[] shipOverloads;
    bool success;
}

struct StartAndEndValidatedDungeonBattleParams {
    uint256 battleSeed;
    uint256 scheduledStart;
    uint256 mapEntity;
    uint256 encounterEntity;
    uint256 shipEntity;
    uint256[] shipOverloads;
    string ipfsUrl;
    string validationHash;
    bool success;
}

struct StartDungeonBattleParams {
    uint256 battleSeed;
    uint256 scheduledStart;
    uint256 mapEntity;
    uint256 encounterEntity;
    uint256 shipEntity;
    uint256[] shipOverloads;
}

struct EndDungeonBattleParams {
    uint256 battleEntity;
    uint256 scheduledStart;
    uint256 mapEntity;
    uint256 encounterEntity;
    bool success;
}

struct DungeonMap {
    DungeonNode[] nodes;
}

struct DungeonNode {
    uint256 nodeId;
    uint256[] enemies;
    ILootSystemV2.Loot[] loots;
    uint256 lootEntity;
}

struct DungeonTrigger {
    uint256 dungeonMapEntity;
    uint256 endAt;
    uint256 startAt;
}

/**
 * @title IDungeonSystemV2
 *
 * This is where outside users will interact with the dungeon system. It will
 * proxy all other calls to the map, battle, and progress systems.
 */
interface IDungeonSystemV3 {
    /**
     * @dev Returns the dungeon trigger, for use in Unity display/setup.
     * @param scheduledStartTimestamp Id of the dungeon trigger to preview.
     * @return dungeonMap Dungeon node data.
     */
    function getDungeonTriggerByIndex(
        uint256 scheduledStartTimestamp
    ) external returns (DungeonTrigger memory);

    /**
     * @dev Returns the dungeon trigger, for debugging purposes.
     * @param scheduledStartTimestamp Start timestamp of the dungeon trigger.
     * @return dungeonTrigger Dungeon trigger data.
     */
    function getDungeonTriggerByStartTimestamp(
        uint256 scheduledStartTimestamp
    ) external returns (DungeonTrigger memory);

    /**
     * @dev Returns the dungeon map, for use in Unity display/setup.
     * @param mapEntity Id of the dungeon trigger to preview.
     * @return dungeonMap Dungeon node data.
     */
    function getDungeonMapById(
        uint256 mapEntity
    ) external returns (DungeonMap memory);

    /**
     * @dev Returns the dungeon map, for use in Unity display/setup.
     * @param scheduleIndex Id of the dungeon trigger to preview.
     * @return dungeonMap Dungeon node data.
     */
    function getDungeonMapByScheduleIndex(
        uint256 scheduleIndex
    ) external returns (DungeonMap memory);

    /**
     * @dev Returns the dungeon node, for use in Unity display/setup.
     * @param encounterEntity Id of the node within the dungeon to preview.
     * @return dungeonNode Dungeon node data.
     */
    function getDungeonNode(
        uint256 encounterEntity
    ) external returns (DungeonNode memory);

    /**
     * @dev Start the battle for a dungeon node.
     * @param params Data for an started battle.
     * @return uint256 The corresponding battle entity that has been started.
     */
    function startDungeonBattle(
        StartDungeonBattleParams calldata params
    ) external returns (uint256);

    /**
     * @dev Finish the battle for a dungeon node.
     * @param params Data for an ended battle.
     */
    function endDungeonBattle(EndDungeonBattleParams calldata params) external;

    /**
     * A single call to manage starting and ending the battle for a dungeon node.
     * @param params Data for an started and ended battle.
     */
    function startAndEndDungeonBattle(
        StartAndEndDungeonBattleParams calldata params
    ) external;

    /**
     * @dev Get the extra time for dungeon completion.
     * @return uint256
     */
    function getExtraTimeForDungeonCompletion() external view returns (uint256);

    /**
     * @dev Get the current state of the player through the dungeon.
     * @param account The account to get the state for
     * @param dungeonEntity The dungeon to get the state for
     * @return uint256  The current node
     * @return DungeonNodeProgressState  The player's state in the current node
     */
    function getCurrentPlayerState(
        address account,
        uint256 dungeonEntity
    ) external view returns (uint256, DungeonNodeProgressState);

    /**
     * @dev Return the state of the dungeon overall for the player.
     * @param account The account to get the state for
     * @param dungeonScheduledStart The dungeon to get the state for
     * @return bool  True if the player has completed the dungeon, false otherwise.
     */
    function isDungeonMapCompleteForAccount(
        address account,
        uint256 dungeonScheduledStart
    ) external view returns (bool);
}
