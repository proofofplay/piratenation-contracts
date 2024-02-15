// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IComponent} from "./IComponent.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";
import "../GameRegistryConsumerV2.sol";

/**
 * @title BaseComponent
 * @notice Base component class, strongly derived from mud.dev
 */
abstract contract BaseComponent is IComponent, GameRegistryConsumerV2 {
    /// @notice Mapping from entity id to value in this component
    mapping(uint256 => bytes) internal entityToValue;

    /** SETUP **/

    /**
     * Initializer for this upgradeable contract
     *
     * @param _gameRegistryAddress Address of the GameRegistry contract
     * @param id ID of the component being created
     */
    constructor(
        address _gameRegistryAddress,
        uint256 id
    ) GameRegistryConsumerV2(_gameRegistryAddress, id) {
        // Do nothing
    }

    /** EXTERNAL **/

    /**
     * Set the given component value for the given entity.
     *
     * @param entity Entity to set the value for.
     * @param value Value to set for the given entity.
     */
    function setBytes(
        uint256 entity,
        bytes memory value
    ) public override onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _set(entity, value);
    }

    /**
     * Remove the given entity from this component.
     *
     * @param entity Entity to remove from this component.
     */
    function remove(
        uint256 entity
    ) public override onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _remove(entity);
    }

    /**
     * Check whether the given entity has a value in this component.
     *
     * @param entity Entity to check whether it has a value in this component for.
     */
    function has(uint256 entity) public view virtual override returns (bool) {
        return entityToValue[entity].length != 0;
    }

    /**
     * Get the raw (abi-encoded) value of the given entity in this component.
     *
     * @param entity Entity to get the raw value in this component for.
     */
    function getBytes(
        uint256 entity
    ) public view virtual override returns (bytes memory) {
        return entityToValue[entity];
    }

    /** INTERNAL */

    /**
     * Set the given component value for the given entity.
     *
     * @param entity Entity to set the value for.
     * @param value Value to set for the given entity.
     */
    function _set(uint256 entity, bytes memory value) internal virtual {
        // Store the entity's value;
        entityToValue[entity] = value;

        // Emit global event
        gameRegistry.registerComponentValueSet(entity, value);
    }

    /**
     * Remove the given entity from this component.
     *
     * @param entity Entity to remove from this component.
     */
    function _remove(uint256 entity) internal virtual {
        // Remove the entity from the mapping
        delete entityToValue[entity];

        // Emit global event
        gameRegistry.registerComponentValueRemoved(entity);
    }
}
