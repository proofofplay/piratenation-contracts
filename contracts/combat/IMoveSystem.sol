// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

uint256 constant ID = uint256(keccak256("game.piratenation.coremovesystem"));

/**
 * @title IMoveSystem
 * @dev NOT IN USE YET; HERE FOR REFERENCE
 *
 * IMoveSystem is an interface for defining and accessing combatant moves.
 */
interface IMoveSystem {
    /**
     * @dev Takes a moveId and returns stat modifiers for CombatStats
     * @dev Modifier order determined in SoT document
     * @param moveId move identifier to lookup modifiers for
     * @return CombatStats stat modifiers for provided moveId
     */
    function getCombatModifiers(
        uint256 moveId
    ) external view returns (int256[] memory);
}
