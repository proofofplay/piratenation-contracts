// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title ICombatable
 *
 * ICombatable is an interface for defining how different NFTs can have combat with one an other.
 */
interface ICombatable {
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
}
