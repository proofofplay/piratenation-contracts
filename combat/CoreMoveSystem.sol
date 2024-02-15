// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {MINTER_ROLE} from "../Constants.sol";
import {IGameGlobals, ID as GAME_GLOBALS_ID} from "../gameglobals/IGameGlobals.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {IMoveSystem, ID} from "./IMoveSystem.sol";

// Core move set
uint256 constant POWER_STRIKE_ID = uint256(
    keccak256("coremovesystem.move.powerstrike")
);
uint256 constant NORMAL_STRIKE_ID = uint256(
    keccak256("coremovesystem.move.normalstrike")
);
uint256 constant EVASIVE_ACTION_ID = uint256(
    keccak256("coremovesystem.move.evasiveaction")
);
uint256 constant CAREFUL_AIM_ID = uint256(
    keccak256("coremovesystem.move.carefulaim")
);
uint256 constant DIRTY_TACTICS_ID = uint256(
    keccak256("coremovesystem.move.dirtytactics")
);
uint256 constant QUICK_SHOT_ID = uint256(
    keccak256("coremovesystem.move.quickshot")
);

enum MoveTypes {
    UNDEFINED,
    POWER_STRIKE,
    NORMAL_STRIKE,
    EVASIVE_ACTION,
    CAREFUL_AIM,
    DIRTY_TACTICS,
    QUICK_SHOT,
    length // This must remain as last member in enum; currently == 7
}

/**
 * @title CoreMoveSystem
 *
 * Supplies CombatStats modifiers given a move selection.
 * Currently all opponents share the same move set.
 */
contract CoreMoveSystem is GameRegistryConsumerUpgradeable, IMoveSystem {
    /** MEMBERS **/

    mapping(uint256 => uint256) _moveIdToGlobal;

    /** ERRORS **/

    /// @notice Invalid moveId to set to mapping
    error InvalidMoveId(uint256 moveId);

    /// @notice Invalid moveIds array to set to mapping
    error InvalidMoveIds();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);

        _moveIdToGlobal[uint256(MoveTypes.POWER_STRIKE)] = POWER_STRIKE_ID;
        _moveIdToGlobal[uint256(MoveTypes.NORMAL_STRIKE)] = NORMAL_STRIKE_ID;
        _moveIdToGlobal[uint256(MoveTypes.EVASIVE_ACTION)] = EVASIVE_ACTION_ID;
        _moveIdToGlobal[uint256(MoveTypes.CAREFUL_AIM)] = CAREFUL_AIM_ID;
        _moveIdToGlobal[uint256(MoveTypes.DIRTY_TACTICS)] = DIRTY_TACTICS_ID;
        _moveIdToGlobal[uint256(MoveTypes.QUICK_SHOT)] = QUICK_SHOT_ID;
    }

    /**
     * @dev Takes a moveId and returns stat modifiers in CombatStats format
     * @param moveId Move identifier to lookup modifiers for
     * @return int256[] Stat modifiers for provided moveId
     */
    function getCombatModifiers(
        uint256 moveId
    ) external view override returns (int256[] memory) {
        // Modifier order determined in SoT document.
        return
            IGameGlobals(_getSystem(GAME_GLOBALS_ID)).getInt256Array(
                _moveIdToGlobal[moveId]
            );
    }

    /**
     * @dev Map an array of moveIds to every valid move
     * @param moveIds An array of moveIds like: [1,2,3,4,5,6]
     */
    function setAllMoves(
        uint256[] calldata moveIds
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        if (moveIds.length != uint256(MoveTypes.length) - 1) {
            revert InvalidMoveIds();
        }

        // Default order of moves defined in SoT
        uint256[6] memory MOVE_IDS = [
            POWER_STRIKE_ID,
            NORMAL_STRIKE_ID,
            EVASIVE_ACTION_ID,
            CAREFUL_AIM_ID,
            DIRTY_TACTICS_ID,
            QUICK_SHOT_ID
        ];

        // For each provided moveId value, map it to a known move in SoT order
        // Example: [1,2,3,4,5,6] would set the default move mappings
        uint256 moveId;
        for (uint8 i = 0; i < moveIds.length; i++) {
            moveId = moveIds[i];

            // Ensure moveId is not MoveTypes.UNDEFINED or out of range
            if (moveId >= uint256(MoveTypes.length) || moveId == 0) {
                revert InvalidMoveId(moveId);
            }

            // Each moveId in array will be mapped to a move constant in expected order
            _moveIdToGlobal[moveId] = MOVE_IDS[i];
        }
    }
}
