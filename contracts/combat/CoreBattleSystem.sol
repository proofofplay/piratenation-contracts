// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";

import {GAME_LOGIC_CONTRACT_ROLE, RANDOMIZER_ROLE} from "../Constants.sol";
import {ICooldownSystem, ID as COOLDOWN_SYSTEM_ID} from "../cooldown/ICooldownSystem.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";

import {ICombatable} from "./ICombatable.sol";

/**
 * Contains data necessary for executing a battle
 */
struct Battle {
    uint256 battleEntity;
    uint256 battleSeed;
    uint256 attackerEntity;
    uint256 defenderEntity;
    uint256[] attackerOverloads;
    uint256[] defenderOverloads;
    ICombatable attackerCombatable;
    ICombatable defenderCombatable;
}

/**
 * @title Core Battle System
 *
 * @dev Simple contract to manage initialization and conclusion of battles
 * @dev Leveraging shared event formats for battle may allow us to avoid gql reindexing
 */
abstract contract CoreBattleSystem is GameRegistryConsumerUpgradeable {
    using Counters for Counters.Counter;

    /** MEMBERS */

    /// @notice Generate a new Battle Id for each new battle created
    Counters.Counter private _latestBattleId;

    /// @notice Mapping to store battleEntity > Battle struct
    mapping(uint256 => Battle) private _battles;

    /// @notice Mapping to store VRF requestId > battleEntity
    mapping(uint256 => uint256) private _requestToBattleEntity;

    /** EVENTS */

    // TODO: consider including ALL data that is required for indexing and for client
    /// @notice emitted when anytime battle + round is started
    event BattlePending(
        uint256 indexed battleEntity,
        uint256 indexed attackerEntity,
        uint256 indexed defenderEntity,
        uint256[] attackerOverloads,
        uint256[] defenderOverloads
    );

    // TODO: consider including ALL data that is required for indexing and for client
    /// @notice emitted when anytime battle + round is started
    event BattleStarted(uint256 indexed battleEntity, uint256 battleSeed);

    // TODO: consider including ALL data that is required for indexing and for client
    /// @notice emitted when anytime battle + round is over
    event BattleEnded(uint256 indexed battleEntity);

    /** ERRORS **/

    /// @notice Required functionality not implemented
    error NotImplemented(string message);

    /**
     * @dev callback executed only in the VRF oracle to resolve randomness for a battle
     * @param requestId identifier for the VRF request
     * @param randomWords an array containing (currently only 1) randomized strings
     */
    function fulfillRandomWordsCallback(
        uint256 requestId,
        uint256[] memory randomWords
    ) external override onlyRole(RANDOMIZER_ROLE) {
        // Store random battle seed
        Battle storage battle = _battles[_requestToBattleEntity[requestId]];

        // Update battle only if it exists; it may have been deleted already
        if (battle.battleEntity != 0) {
            battle.battleSeed = randomWords[0];

            // Emit event
            emit BattleStarted(battle.battleEntity, battle.battleSeed);
        }

        // Clear VRF
        delete _requestToBattleEntity[requestId];
    }

    /**
     * @dev Initializes a battle and kicks off a VRF request for the random battle seed
     * @param attackerEntity A packed address and token ID for the attacker
     * @param defenderEntity A packed address and token ID for the defender
     * @param attackerOverloads Array of entities used to modify combat for the attacker
     * @param defenderOverloads Array of entities used to modify combat for the defender
     * @return battle data initialized for a new battle
     */
    function _createBattle(
        uint256 battleSeed,
        uint256 attackerEntity,
        uint256 defenderEntity,
        uint256[] memory attackerOverloads,
        uint256[] memory defenderOverloads,
        ICombatable attackerCombatable,
        ICombatable defenderCombatable
    ) internal returns (uint256) {
        // Create new battle id
        _latestBattleId.increment();
        uint256 battleEntity = _getBattleEntity(_latestBattleId.current());

        // Initialize battle
        _battles[battleEntity] = Battle({
            battleEntity: battleEntity,
            attackerEntity: attackerEntity,
            defenderEntity: defenderEntity,
            attackerOverloads: attackerOverloads,
            defenderOverloads: defenderOverloads,
            attackerCombatable: attackerCombatable,
            defenderCombatable: defenderCombatable,
            // Instead of VRF callback, store battleSeed from client.
            // This is less secure because seed is unverified, but a better UX.
            battleSeed: battleSeed
        });

        // Request VRF randomness for battle
        // uint256 requestId = _requestRandomWords(1);
        // _requestToBattleEntity[requestId] = battleEntity;

        // Emit event
        emit BattlePending(
            battleEntity,
            attackerEntity,
            defenderEntity,
            attackerOverloads,
            defenderOverloads
        );

        return battleEntity;
    }

    /**
     * @dev Deletes a battle from storage and emits a BattleEnded event
     * @param battleEntity identifier for the desired battle to delete
     */
    function _deleteBattle(uint256 battleEntity) internal {
        delete _battles[battleEntity];
    }

    /**
     * @dev Returns a battle
     * @param battleEntity identifier for the desired battle to retrieve
     * @return battle data pertaining to the battle id if exists
     */
    function _getBattle(
        uint256 battleEntity
    ) internal view returns (Battle memory) {
        return _battles[battleEntity];
    }

    /**
     * @dev Returns a battle entity given the battle id
     * @param battleId internal battle id used to produce the battle entity
     * @return battleEntity unique global identifier given a battleId
     */
    function _getBattleEntity(
        uint256 battleId
    ) internal view returns (uint256) {
        return EntityLibrary.tokenToEntity(address(this), battleId);
    }

    /**
     * @dev provides access to the internal battle id counter, useful for testing
     */
    function _getCurrentBattleId() internal view returns (uint256) {
        return _latestBattleId.current();
    }
}
