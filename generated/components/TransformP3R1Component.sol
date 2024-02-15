// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseStorageComponent, IBaseStorageComponent} from "../../core/components/BaseStorageComponent.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.transformp3r1componentv1"));

struct Layout {
    int64 x;
    int64 y;
    int64 z;
    int64 rotation;
}

library TransformP3R1ComponentStorage {
    bytes32 internal constant STORAGE_SLOT = bytes32(ID);

    // Declare struct for mapping entity to struct
    struct InternalLayout {
        mapping(uint256 => Layout) entityIdToStruct;
    }

    function layout() internal pure returns (InternalLayout storage dataStruct) {
        bytes32 position = STORAGE_SLOT;
        assembly {
            dataStruct.slot := position
        }
    }
}

/**
 * @title TransformP3R1Component
 * @dev Transform P3R1 Component
 *
 * @dev Generated with component version 0.
 */
contract TransformP3R1Component is BaseStorageComponent {
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
        keys = new string[](4);
        values = new TypesLibrary.SchemaValue[](4);
    
        // X axis location
        keys[0] = "x";
        values[0] = TypesLibrary.SchemaValue.INT64;
    
        // Y axis location
        keys[1] = "y";
        values[1] = TypesLibrary.SchemaValue.INT64;
    
        // Z axis location
        keys[2] = "z";
        values[2] = TypesLibrary.SchemaValue.INT64;
    
        // Rotation value
        keys[3] = "rotation";
        values[3] = TypesLibrary.SchemaValue.INT64;
    
    }

    /**
     * Sets the typed value for this component
     *
     * @param entity Entity to get value for 
     * @param value Layout to set for the given entity
     */
    function setValue(
        uint256 entity,
        Layout calldata value
    ) external virtual {
        _setValueToStorage(entity, value);

        // ABI Encode all native types of the struct
        emitSetBytes(
            entity,
            abi.encode(value.x, value.y, value.z, value.rotation)
        );
    }

    /**
     * Batch sets the typed value for this component
     *
     * @param entities Entity to batch set values for
     * @param values Layout to set for the given entities
     */
    function batchSetValue(
        uint256[] calldata entities,
        Layout[] calldata values
    ) external virtual {
        if (entities.length != values.length) {
            revert InvalidBatchData(entities.length, values.length);
        }

        // Set the values in storage
        bytes[] memory encodedValues = new bytes[](entities.length);
        for (uint256 i = 0; i < entities.length; i++) {
            _setValueToStorage(entities[i], values[i]);
            encodedValues[i] = abi.encode(
                values[i].x, values[i].y, values[i].z, values[i].rotation
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
    ) external view virtual returns (Layout memory value) {
        // Get the struct from storage
        value = TransformP3R1ComponentStorage.layout().entityIdToStruct[entity];
    }

    /**
     * Remove the given entity from this component.
     *
     * @param entity Entity to remove from this component.
     */
    function remove(uint256 entity) public virtual {
        // Remove the entity from the component
        delete TransformP3R1ComponentStorage.layout().entityIdToStruct[entity];
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
            delete TransformP3R1ComponentStorage.layout().entityIdToStruct[
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
        Layout
           storage s = TransformP3R1ComponentStorage
               .layout()
               .entityIdToStruct[entity];

        return s.x != 0 ||
           s.y != 0 ||
           s.z != 0 ||
           s.rotation != 0;
    }

    /** INTERNAL **/

    function _setValueToStorage(
        uint256 entity,
        Layout calldata transform
    ) internal {
        Layout storage s = TransformP3R1ComponentStorage
            .layout()
            .entityIdToStruct[entity];

        s.x = transform.x;
        s.y = transform.y;
        s.z = transform.z;
        s.rotation = transform.rotation;
    }
}
