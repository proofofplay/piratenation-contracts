// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../GameRegistryConsumerUpgradeable.sol";

import {StartDungeonBattleParams, DungeonNode} from "./IDungeonSystemV3.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.dungeonbattlesystem.v2")
);

struct EndBattleParams {
    address account;
    uint256 battleEntity;
    bool success;
}

/**
 * @title IDungeonBattleSystemV2
 */
interface IDungeonBattleSystemV2 {
    /**
     * @dev Start a dungeon battle.
     * @param params StartBattleParams
     * @return battleEntity Entity of the battle
     */
    function startBattle(
        address account,
        StartDungeonBattleParams calldata params,
        DungeonNode calldata node
    ) external returns (uint256);

    /**
     * @dev End a dungeon battle.
     * @param params EndBattleParams
     */
    function endBattle(EndBattleParams calldata params) external;
}
