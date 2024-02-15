// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

uint256 constant ID = uint256(keccak256("game.piratenation.cooldownsystem"));

/**
 * @title ICooldownSystem
 *
 * Interface for general CooldownSystem
 */
interface ICooldownSystem {
    /**
     * @dev Map an entity to a system cooldown Id to a timeStamp
     * @param entity can be address, nft, round, ability, etc
     * @param cooldownId keccak to system using cooldown
     * @param cooldownTime cooldown time limit to set for entity, example 12 hours
     * @return true if block.timestamp is past timeStamp + cooldownTime
     */
    function updateAndCheckCooldown(
        uint256 entity,
        uint256 cooldownId,
        uint32 cooldownTime
    ) external returns (bool);

    /**
     * @dev View function to check if entity is in cooldown
     * @param entity can be address, nft, round, ability, etc
     * @param cooldownId keccak to system using cooldown
     * @return true if block.timestamp is before entities cooldown timestamp, meaning entity is still in cooldown
     */
    function isInCooldown(
        uint256 entity,
        uint256 cooldownId
    ) external view returns (bool);

    /**
     * @dev View function return entity cooldown timestamp
     * @param entity can be address, nft, round, ability, etc
     * @param cooldownId keccak to system using cooldown
     * @return uint32 entity cooldown timestamp
     */
    function getCooldown(
        uint256 entity,
        uint256 cooldownId
    ) external view returns (uint32);

    /**
     * @dev Function for cleaning up an entity cooldown timestamp
     * @param entity can be address, nft, round, ability, etc
     * @param cooldownId keccak to system using cooldown
     */
    function deleteCooldown(uint256 entity, uint cooldownId) external;

    /**
     * @dev Function to reduce desired cooldown by cooldownTime
     * @param entity can be address, nft, round, ability, etc
     * @param cooldownId keccak to system using cooldown
     * @param cooldownTime time to reduce cooldown by
     */
    function reduceCooldown(
        uint256 entity,
        uint256 cooldownId,
        uint32 cooldownTime
    ) external;
}
