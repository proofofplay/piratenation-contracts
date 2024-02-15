// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {ID as ENTITY_SYSTEM_ID, IEntitySystem} from "./IEntitySystem.sol";

import "../GameRegistryConsumerUpgradeable.sol";
import "./EntityLibrary.sol";

/**
 * @title EntityConsumer contract. Base contract to make it easy for other contracts to implement entity-related functionality
 */
abstract contract EntityConsumer is GameRegistryConsumerUpgradeable {
    /** ERRORS **/

    /// @notice Invalid LocalId
    error InvalidLocalId();

    /** MODIFIERS **/

    modifier checkLocalId(uint256 _localId) {
        if (_localId <= 0) {
            revert InvalidLocalId();
        }
        _;
    }

    /** SETUP **/

    /** Initializer function for upgradeable contract */
    function initialize(
        address gameRegistryAddress,
        uint256 _id
    ) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, _id);
    }

    /**
     * @return true if an entity withthe given local id exists
     */
    function entityExists(uint256 _localId) external view returns (bool) {
        uint256 _entityId = EntityLibrary.tokenToEntity(
            address(this),
            _localId
        );
        return _entitySystem().entityExists(_entityId);
    }

    /** INTERNAL **/

    function _entitySystem() internal view returns (IEntitySystem) {
        IEntitySystem system = IEntitySystem(_getSystem(ENTITY_SYSTEM_ID));
        return system;
    }

    /**
     * @dev Internal
     */
    function _createEntity(
        uint256 _localId
    ) internal checkLocalId(_localId) returns (uint256) {
        // Generate unique GUID Entity ID
        uint256 _entityId = EntityLibrary.tokenToEntity(
            address(this),
            _localId
        );
        _entitySystem().createEntity(_entityId);
        return _entityId;
    }

    /**
     * Removes the entity with the given local id
     */
    function _removeEntity(uint256 _localId) internal checkLocalId(_localId) {
        uint256 _entityId = EntityLibrary.tokenToEntity(
            address(this),
            _localId
        );
        _entitySystem().removeEntity(_entityId);
    }
}
