// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ITraitsProvider} from "../interfaces/ITraitsProvider.sol";

// NOTE: Must keep IMoveSystem globals + SoT in sync with any changes to CombatStats
struct CombatStats {
    int64 damage;
    int64 evasion;
    int64 speed;
    int64 accuracy;
    uint64 health;
    uint64 affinity;
    uint64 move;
}

/**
 * @title ICombatable
 *
 * ICombatable is an interface for defining how different NFTs can have combat with one an other.
 */
interface ICombatable {
    /**
     * @dev Function returns CombatStats with calculations from CoreMoveSystem + Roll + Overloads applied to them
     * @param entityId A packed tokenId and Address
     * @param roll VRF result[0]
     * @param moveId A Uint of what the move the Attack is doing
     * @param overloads An optional array of overload NFTs (if there is an another NFT on the boat)
     * @return CombatStats newly calculated CombatStats
     */
    function getCombatStats(
        uint256 entityId,
        uint256 roll,
        uint256 moveId,
        uint256[] calldata overloads
    ) external view returns (CombatStats memory);

    /**
     * @dev Decrease the current_health trait of entityId
     * @param entityId A packed tokenId and Address
     * @param amount amount to reduce entityIds health
     * @return newHealth New current health of entityId after damage is taken
     */
    function decreaseHealth(
        uint256 entityId,
        uint256 amount
    ) external returns (uint256 newHealth);

    /**
     * @dev Check if entityId can be attacked by checking its health, if boss then check if active/inactive
     * @param entityId A packed tokenId and Address
     * @param overloads An optional array of overload NFTs (if there is an another NFT on the boat)
     * @return boolean if entityId can be attacked
     */
    function canBeAttacked(
        uint256 entityId,
        uint256[] calldata overloads
    ) external view returns (bool);

    /**
     * @dev Check if entityId health > 0 && caller is owner of entityId && owner of overloads
     * @param caller Address of msg.sender : used for checking if caller is owner of entityId & overloads
     * @param entityId A packed tokenId and Address
     * @param overloads An optional array of overload NFTs (if there is an another NFT on the boat)
     * @return boolean If the boss can attack
     */
    function canAttack(
        address caller,
        uint256 entityId,
        uint256[] calldata overloads
    ) external view returns (bool);

    /**
     * @dev Helper func return current health of entityId without redeclaring TraitsProvider
     */
    function getCurrentHealth(
        uint256 entityId,
        ITraitsProvider traitsProvider
    ) external view returns (uint256);
}
