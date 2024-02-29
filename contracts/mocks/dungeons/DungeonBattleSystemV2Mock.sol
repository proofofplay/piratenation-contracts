// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../../dungeons/DungeonBattleSystemV2.sol";

contract DungeonBattleSystemV2Mock is DungeonBattleSystemV2 {
    function getCurrentBattleId() external view returns (uint256) {
        return _getCurrentBattleId();
    }

    function getBattle(
        uint256 battleEntity
    ) external view returns (Battle memory) {
        return _getBattle(battleEntity);
    }
}
