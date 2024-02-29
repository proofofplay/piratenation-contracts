// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {CombatStats, ICombatable} from "../../combat/ICombatable.sol";
import {ITraitsProvider} from "../../interfaces/ITraitsProvider.sol";

/**
 * A proof of concept definition of how pirates could have combat stats to test ICombatable.
 */
contract PirateCombatMock is ICombatable {
    mapping(uint256 => uint256) private _pirateHealth;

    function preparePirate(uint256 entityId) external {
        _pirateHealth[entityId] = 20;
    }

    function getCombatStats(
        uint256,
        uint256,
        uint256 moveId,
        uint256[] calldata
    ) external pure returns (CombatStats memory) {
        return
            CombatStats({
                damage: 0,
                evasion: 20,
                speed: 20,
                accuracy: 20,
                health: 20,
                affinity: 1,
                move: uint64(moveId)
            });
    }

    function decreaseHealth(
        uint256 entityId,
        uint256 amount
    ) external returns (uint256 newHealth) {
        _pirateHealth[entityId] = _pirateHealth[entityId] - amount;
        return _pirateHealth[entityId];
    }

    function canBeAttacked(
        uint256 entityId,
        uint256[] calldata
    ) external view returns (bool) {
        if (_pirateHealth[entityId] > 0) {
            return true;
        }
        return false;
    }

    function canAttack(
        address,
        uint256 entityId,
        uint256[] calldata
    ) external view returns (bool) {
        if (_pirateHealth[entityId] > 0) {
            return true;
        }
        return false;
    }

    function getCurrentHealth(
        uint256 entityId,
        ITraitsProvider
    ) external view returns (uint256) {
        return _pirateHealth[entityId];
    }
}
