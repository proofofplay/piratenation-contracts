// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseStorageComponent, IBaseStorageComponent} from "../../core/components/BaseStorageComponent.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.sceneobjectparentcomponentv1"));

struct SceneObjectParent {
    uint256 parentEntity;
}

library SceneObjectParentComponentStorage {
    bytes32 internal constant STORAGE_SLOT = bytes32(ID);

    // Declare struct for mapping entity to struct
    struct InternalLayout {
        mapping(uint256 => SceneObjectParent) entityIdToStruct;
    }

    function layout() internal pure returns (InternalLayout storage dataStruct) {
        bytes32 position = STORAGE_SLOT;
        assembly {
            dataStruct.slot := position
        }
    }
}

/**
 * @title SceneObjectParentComponent
 * @dev Scene Object Parent Component
 *
 * @dev Generated with component version 0.
 */
contract SceneObjectParentComponent is BaseStorageComponent {
    /** SETUP **/

    /** Sets the GameRegistry contract address for this contract  */
    constructor(
        address gameRegistryAddress
    ) BaseStorageComponent(gameRegistryAddress, ID) {
        // Do nothing
    }

    /**
     * @inheritdoc IBaseStorageComponent
     */
    function getSchema()
        public
        pure
        override
        returns (string[] memory keys, TypesLibrary.SchemaValue[] memory values)
    {
        keys = new string[](1);
        values = new TypesLibrary.SchemaValue[](1);
    
        // Entity ID of the parent
        keys[0] = "value";
        values[0] = TypesLibrary.SchemaValue.UINT256;
    
    }

    /**
     * Sets the typed value for this component
     *
     * @param entity Entity to get value for 
     * @param value SceneObjectParent to set for the given entity
     */
    function setValue(
        uint256 entity,
        SceneObjectParent calldata value
    ) external virtual {
        _setValueToStorage(entity, value);

        // ABI Encode all native types of the struct
        emitSetBytes(
            entity,
            abi.encode(value.parentEntity)
        );
    }

    /**
     * Batch sets the typed value for this component
     *
     * @param entities Entity to batch set values for
     * @param values SceneObjectParent to set for the given entities
     */
    function batchSetValue(
        uint256[] calldata entities,
        SceneObjectParent[] calldata values
    ) external virtual {
        if (entities.length != values.length) {
            revert InvalidBatchData(entities.length, values.length);
        }

        // Set the values in storage
        bytes[] memory encodedValues = new bytes[](entities.length);
        for (uint256 i = 0; i < entities.length; i++) {
            _setValueToStorage(entities[i], values[i]);
            encodedValues[i] = abi.encode(
                values[i].parentEntity
            );
        }

        // ABI Encode all native types of the struct
        emitBatchSetBytes(entities, encodedValues);
    }

    /**
     * Returns the typed value for this component
     *
     * @param entity Entity to get value for
     */
    function getValue(
        uint256 entity
    ) external view virtual returns (SceneObjectParent memory value) {
        // Get the struct from storage
        value = SceneObjectParentComponentStorage.layout().entityIdToStruct[entity];
    }

    /**
     * Remove the given entity from this component.
     *
     * @param entity Entity to remove from this component.
     */
    function remove(uint256 entity) public virtual {
        // Remove the entity from the component
        delete SceneObjectParentComponentStorage.layout().entityIdToStruct[entity];
        emitRemoveBytes(entity);
    }

    /**
     * Batch remove the given entities from this component.
     *
     * @param entities Entities to remove from this component.
     */
    function batchRemove(uint256[] calldata entities) public virtual {
        // Remove the entities from the component
        for (uint256 i = 0; i < entities.length; i++) {
            delete SceneObjectParentComponentStorage.layout().entityIdToStruct[
                entities[i]
            ];
        }
        emitBatchRemoveBytes(entities);
    }

    /**
     * Check whether the given entity has a value in this component.
     *
     * @param entity Entity to check whether it has a value in this component for.
     */
    function has(uint256 entity) public view virtual returns (bool) {
        SceneObjectParent
           storage s = SceneObjectParentComponentStorage
               .layout()
               .entityIdToStruct[entity];

        return s.parentEntity != 0;
    }

    /** INTERNAL **/

    function _setValueToStorage(
        uint256 entity,
        SceneObjectParent calldata transform
    ) internal {
        SceneObjectParent storage s = SceneObjectParentComponentStorage
            .layout()
            .entityIdToStruct[entity];

        s.parentEntity = transform.parentEntity;
    }
}
