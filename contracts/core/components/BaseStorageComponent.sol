// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IBaseStorageComponent} from "./IBaseStorageComponent.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";
import "../GameRegistryConsumerV2.sol";

/**
 * @title BaseStorageComponent
 * @notice Base storage component class
 */
abstract contract BaseStorageComponent is
    IBaseStorageComponent,
    GameRegistryConsumerV2
{
    /// @notice Invalid data count compared to number of entity count
    error InvalidBatchData(uint256 entityCount, uint256 valueCount);

    /** SETUP **/

    /**
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
     * Emit the raw bytes value set for this component
     * @param entity Entity to set the value for.
     * @param value Value to set for the given entity.
     */
    function emitSetBytes(
        uint256 entity,
        bytes memory value
    ) public override onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _emitSetBytes(entity, value);
    }

    /**
     * Batch emit the raw bytes values set for this component
     * @param entities Array of entities to set values for.
     * @param values Array of values to set for a given entity.
     */
    function emitBatchSetBytes(
        uint256[] calldata entities,
        bytes[] memory values
    ) public override onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _emitBatchSetBytes(entities, values);
    }

    /**
     * Emit when removing an entity from this component
     * @param entity Entity to remove
     */
    function emitRemoveBytes(
        uint256 entity
    ) public override onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _emitRemoveBytes(entity);
    }

    /**
     * Batch emit when removing entities from this component
     * @param entities Array of entities to remove from this component.
     */
    function emitBatchRemoveBytes(
        uint256[] calldata entities
    ) public override onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _emitBatchRemoveBytes(entities);
    }

    /** INTERNAL */

    /**
     * Use GameRegistry to trigger emit when setting
     * @param entity Entity to set the value for.
     * @param value Value to set for the given entity.
     */
    function _emitSetBytes(
        uint256 entity,
        bytes memory value
    ) internal virtual {
        // Emit global event
        gameRegistry.registerComponentValueSet(entity, value);
    }

    /**
     * Use GameRegistry to trigger emit when setting
     * @param entities Array of entities to set values for.
     * @param values Array of values to set for a given entity.
     */
    function _emitBatchSetBytes(
        uint256[] calldata entities,
        bytes[] memory values
    ) internal virtual {
        // Emit global event
        gameRegistry.batchRegisterComponentValueSet(entities, values);
    }

    /**
     * Use GameRegistry to trigger emit when removing
     * @param entity Entity to remove from this component.
     */
    function _emitRemoveBytes(uint256 entity) internal virtual {
        // Emit global event
        gameRegistry.registerComponentValueRemoved(entity);
    }

    /**
     * Use GameRegistry to trigger emit when removing
     * @param entities Array of entities to remove from this component.
     */
    function _emitBatchRemoveBytes(
        uint256[] calldata entities
    ) internal virtual {
        // Emit global event
        gameRegistry.batchRegisterComponentValueRemoved(entities);
    }
}
