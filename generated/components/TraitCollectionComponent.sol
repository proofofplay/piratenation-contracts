// SPDX-License-Identifier: MIT
// Auto-generated using Mage CLI codegen (v1) - DO NOT EDIT

pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseStorageComponentV2, IBaseStorageComponentV2} from "../../core/components/BaseStorageComponentV2.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.traitcollectioncomponent.v3")
);

struct Layout {
    uint256[] componentIds;
    bool[] isAttribute;
}

library TraitCollectionComponentStorage {
    bytes32 internal constant STORAGE_SLOT = bytes32(ID);

    // Declare struct for mapping entity to struct
    struct InternalLayout {
        mapping(uint256 => Layout) entityIdToStruct;
    }

    function layout()
        internal
        pure
        returns (InternalLayout storage dataStruct)
    {
        bytes32 position = STORAGE_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            dataStruct.slot := position
        }
    }
}

/**
 * @title TraitCollectionComponent
 * @dev Component for storing tokenURI component ID&#39;s parented to a token entity
 */
contract TraitCollectionComponent is BaseStorageComponentV2 {
    /** SETUP **/

    /** Sets the GameRegistry contract address for this contract  */
    constructor(
        address gameRegistryAddress
    ) BaseStorageComponentV2(gameRegistryAddress, ID) {
        // Do nothing
    }

    /**
     * @inheritdoc IBaseStorageComponentV2
     */
    function getSchema()
        public
        pure
        override
        returns (string[] memory keys, TypesLibrary.SchemaValue[] memory values)
    {
        keys = new string[](2);
        values = new TypesLibrary.SchemaValue[](2);

        // Array of component IDs to be included in the tokenURI
        keys[0] = "component_ids";
        values[0] = TypesLibrary.SchemaValue.UINT256_ARRAY;

        // Array of bools indicating if the component is an attribute
        keys[1] = "is_attribute";
        values[1] = TypesLibrary.SchemaValue.BOOL_ARRAY;
    }

    /**
     * Sets the typed value for this component
     *
     * @param entity Entity to get value for
     * @param value Layout to set for the given entity
     */
    function setLayoutValue(
        uint256 entity,
        Layout calldata value
    ) external virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _setValue(entity, value);
    }

    /**
     * Sets the native value for this component
     *
     * @param entity Entity to get value for
     * @param componentIds Array of component IDs to be included in the tokenURI
     * @param isAttribute Array of bools indicating if the component is an attribute
     */
    function setValue(
        uint256 entity,
        uint256[] memory componentIds,
        bool[] memory isAttribute
    ) external virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _setValue(entity, Layout(componentIds, isAttribute));
    }

    /**
     * Appends to the components.
     *
     * @param entity Entity to get value for
     * @param values Layout to set for the given entity
     */
    function append(
        uint256 entity,
        Layout memory values
    ) public virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        Layout storage s = TraitCollectionComponentStorage
            .layout()
            .entityIdToStruct[entity];
        for (uint256 i = 0; i < values.componentIds.length; i++) {
            s.componentIds.push(values.componentIds[i]);
            s.isAttribute.push(values.isAttribute[i]);
        }

        // ABI Encode all native types of the struct
        _emitSetBytes(entity, abi.encode(s.componentIds, s.isAttribute));
    }

    /**
     * @dev Removes the values at a set of given indexes
     * @param entity Entity to get value for
     * @param indexes Indexes to remove
     */
    function removeValueAtIndexes(
        uint256 entity,
        uint256[] calldata indexes
    ) public virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        Layout storage s = TraitCollectionComponentStorage
            .layout()
            .entityIdToStruct[entity];

        for (uint256 i = 0; i < indexes.length; i++) {
            uint256 indexToRemove = indexes[i];
            // Get the last index
            uint256 lastIndexInArray = s.componentIds.length - 1;
            // Move the last value to the index to pop
            if (indexToRemove != lastIndexInArray) {
                s.componentIds[indexToRemove] = s.componentIds[
                    lastIndexInArray
                ];
                s.isAttribute[indexToRemove] = s.isAttribute[lastIndexInArray];
            }
            // Pop the last value
            s.componentIds.pop();
            s.isAttribute.pop();
        }

        // ABI Encode all native types of the struct
        _emitSetBytes(entity, abi.encode(s.componentIds, s.isAttribute));
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
    ) external virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        if (entities.length != values.length) {
            revert InvalidBatchData(entities.length, values.length);
        }

        // Set the values in storage
        bytes[] memory encodedValues = new bytes[](entities.length);
        for (uint256 i = 0; i < entities.length; i++) {
            _setValueToStorage(entities[i], values[i]);
            encodedValues[i] = _getEncodedValues(values[i]);
        }

        // ABI Encode all native types of the struct
        _emitBatchSetBytes(entities, encodedValues);
    }

    /**
     * Returns the typed value for this component
     *
     * @param entity Entity to get value for
     * @return value Layout value for the given entity
     */
    function getLayoutValue(
        uint256 entity
    ) external view virtual returns (Layout memory value) {
        // Get the struct from storage
        value = TraitCollectionComponentStorage.layout().entityIdToStruct[
            entity
        ];
    }

    /**
     * Returns the native values for this component
     *
     * @param entity Entity to get value for
     * @return componentIds Array of component IDs to be included in the tokenURI
     * @return isAttribute Array of bools indicating if the component is an attribute
     */
    function getValue(
        uint256 entity
    )
        external
        view
        virtual
        returns (uint256[] memory componentIds, bool[] memory isAttribute)
    {
        if (has(entity)) {
            Layout memory s = TraitCollectionComponentStorage
                .layout()
                .entityIdToStruct[entity];
            (componentIds, isAttribute) = abi.decode(
                _getEncodedValues(s),
                (uint256[], bool[])
            );
        }
    }

    /**
     * Returns an array of byte values for each field of this component.
     *
     * @param entity Entity to build array of byte values for.
     */
    function getByteValues(
        uint256 entity
    ) external view virtual returns (bytes[] memory values) {
        // Get the struct from storage
        Layout storage s = TraitCollectionComponentStorage
            .layout()
            .entityIdToStruct[entity];

        // ABI Encode all fields of the struct and add to values array
        values = new bytes[](2);
        values[0] = abi.encode(s.componentIds);
        values[1] = abi.encode(s.isAttribute);
    }

    /**
     * Returns the bytes value for this component
     *
     * @param entity Entity to get value for
     */
    function getBytes(
        uint256 entity
    ) external view returns (bytes memory value) {
        Layout memory s = TraitCollectionComponentStorage
            .layout()
            .entityIdToStruct[entity];
        value = _getEncodedValues(s);
    }

    /**
     * Sets the value of this component using a byte array
     *
     * @param entity Entity to set value for
     */
    function setBytes(
        uint256 entity,
        bytes calldata value
    ) external onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        Layout memory s = TraitCollectionComponentStorage
            .layout()
            .entityIdToStruct[entity];
        (s.componentIds, s.isAttribute) = abi.decode(
            value,
            (uint256[], bool[])
        );
        _setValueToStorage(entity, s);

        // ABI Encode all native types of the struct
        _emitSetBytes(entity, value);
    }

    /**
     * Remove the given entity from this component.
     *
     * @param entity Entity to remove from this component.
     */
    function remove(
        uint256 entity
    ) public virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        // Remove the entity from the component
        delete TraitCollectionComponentStorage.layout().entityIdToStruct[
            entity
        ];
        _emitRemoveBytes(entity);
    }

    /**
     * Batch remove the given entities from this component.
     *
     * @param entities Entities to remove from this component.
     */
    function batchRemove(
        uint256[] calldata entities
    ) public virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        // Remove the entities from the component
        for (uint256 i = 0; i < entities.length; i++) {
            delete TraitCollectionComponentStorage.layout().entityIdToStruct[
                entities[i]
            ];
        }
        _emitBatchRemoveBytes(entities);
    }

    /**
     * Check whether the given entity has a value in this component.
     *
     * @param entity Entity to check whether it has a value in this component for.
     */
    function has(uint256 entity) public view virtual returns (bool) {
        return gameRegistry.getEntityHasComponent(entity, ID);
    }

    /** INTERNAL **/

    function _setValueToStorage(uint256 entity, Layout memory value) internal {
        Layout storage s = TraitCollectionComponentStorage
            .layout()
            .entityIdToStruct[entity];

        s.componentIds = value.componentIds;
        s.isAttribute = value.isAttribute;
    }

    function _setValue(uint256 entity, Layout memory value) internal {
        _setValueToStorage(entity, value);

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(value.componentIds, value.isAttribute)
        );
    }

    function _getEncodedValues(
        Layout memory value
    ) internal pure returns (bytes memory) {
        return abi.encode(value.componentIds, value.isAttribute);
    }
}
