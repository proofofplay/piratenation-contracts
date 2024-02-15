// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {ID, IEntitySystem} from "./IEntitySystem.sol";

import "../GameRegistryConsumerUpgradeable.sol";
import "./EntityLibrary.sol";

/**
 * @title EntitySystem Upgradeable Contract
 */
contract EntitySystem is GameRegistryConsumerUpgradeable, IEntitySystem {
    /** MEMBERS **/
    mapping(uint256 => bool) createdEntities;

    /** EVENTS **/
    /// @notice Emitted when an Entity is created
    event EntityCreated(uint256 indexed entityId);
    /// @notice Emitted when an Entity is removed
    event EntityRemoved(uint256 indexed entityId);

    /** ERRORS **/

    /// @notice Entity ID does not exist
    error EntityIdNotExists();

    /// @notice Entity ID already exists
    error EntityIdExists();

    /// @notice Invalid Token
    error InvalidToken();

    /** MODIFIERS **/

    modifier checkToken(address addr, uint256 entityId) {
        if (entityId <= 0 || addr == address(0)) {
            revert InvalidToken();
        }
        _;
    }

    /** SETUP **/

    /** Initializer function for upgradeable contract */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /** EXTERNAL **/

    /**
     * Creates a new entity with the given id, errors if it already exists
     *
     * @param entityId Id of the entity to create
     * @return The entity id that was created
     */
    function createEntity(
        uint256 entityId
    ) external override onlyRole(GAME_LOGIC_CONTRACT_ROLE) returns (uint256) {
        // Check if EntityId exists
        if (createdEntities[entityId]) {
            revert EntityIdExists();
        }
        createdEntities[entityId] = true;
        emit EntityCreated(entityId);
        return entityId;
    }

    /**
     * Removes a previously created entity
     
     * @param entityId Id of the entity to remove
     */
    function removeEntity(
        uint256 entityId
    ) external override onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        // Check if EntityId does not exist
        if (!createdEntities[entityId]) {
            revert EntityIdNotExists();
        }
        delete (createdEntities[entityId]);
        emit EntityRemoved(entityId);
    }

    /** @return true if entity exists */
    function entityExists(
        uint256 entityId
    ) external view override returns (bool) {
        return createdEntities[entityId];
    }

    /** INTERNAL **/

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165) returns (bool) {
        return interfaceId == type(IEntitySystem).interfaceId;
    }
}
