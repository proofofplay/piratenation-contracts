// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.entitysystem"));

/**
 * @title Interface for EntitySystem
 */
interface IEntitySystem is IERC165 {
    /**
     * Creates a new entity with the given id, errors if it already exists
     *
     * @param entityId Id of the entity to create
     * @return The entity id that was created
     */
    function createEntity(uint256 entityId) external returns (uint256);

    /**
     * Removes a previously created entity
     
     * @param entityId Id of the entity to remove
     */
    function removeEntity(uint256 entityId) external;

    /**
     * @dev Check if EntityID exists
     * @param entityId ID of entity to check
     * @return true if entity exists
     */
    function entityExists(uint256 entityId) external view returns (bool);
}
