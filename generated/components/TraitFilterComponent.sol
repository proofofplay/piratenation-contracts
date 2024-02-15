// SPDX-License-Identifier: MIT
// Auto-generated using Mage CLI codegen (v1) - DO NOT EDIT

pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseStorageComponentV2, IBaseStorageComponentV2} from "../../core/components/BaseStorageComponentV2.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.traitfiltercomponent.v1")
);

struct Layout {
    uint256[] filterType;
    uint256[] traitEntity;
    int256[] traitValue;
}

library TraitFilterComponentStorage {
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
 * @title TraitFilterComponent
 * @dev Defines an array of trait filters. Trait filters are simple logic statements that can be used to filter entities based on their traits.
 */
contract TraitFilterComponent is BaseStorageComponentV2 {
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
        keys = new string[](3);
        values = new TypesLibrary.SchemaValue[](3);

        // Operation to perform for this filter
        keys[0] = "filter_type";
        values[0] = TypesLibrary.SchemaValue.UINT256_ARRAY;

        // Trait to check filter against
        keys[1] = "trait_entity";
        values[1] = TypesLibrary.SchemaValue.UINT256_ARRAY;

        // The value of the trait to filter
        keys[2] = "trait_value";
        values[2] = TypesLibrary.SchemaValue.INT256_ARRAY;
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
     * @param filterType Operation to perform for this filter
     * @param traitEntity Trait to check filter against
     * @param traitValue The value of the trait to filter
     */
    function setValue(
        uint256 entity,
        uint256[] memory filterType,
        uint256[] memory traitEntity,
        int256[] memory traitValue
    ) external virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _setValue(entity, Layout(filterType, traitEntity, traitValue));
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
        Layout storage s = TraitFilterComponentStorage
            .layout()
            .entityIdToStruct[entity];
        for (uint256 i = 0; i < values.filterType.length; i++) {
            s.filterType.push(values.filterType[i]);
            s.traitEntity.push(values.traitEntity[i]);
            s.traitValue.push(values.traitValue[i]);
        }

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(s.filterType, s.traitEntity, s.traitValue)
        );
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
        Layout storage s = TraitFilterComponentStorage
            .layout()
            .entityIdToStruct[entity];

        for (uint256 i = 0; i < indexes.length; i++) {
            uint256 indexToRemove = indexes[i];
            // Get the last index
            uint256 lastIndexInArray = s.filterType.length - 1;
            // Move the last value to the index to pop
            if (indexToRemove != lastIndexInArray) {
                s.filterType[indexToRemove] = s.filterType[lastIndexInArray];
                s.traitEntity[indexToRemove] = s.traitEntity[lastIndexInArray];
                s.traitValue[indexToRemove] = s.traitValue[lastIndexInArray];
            }
            // Pop the last value
            s.filterType.pop();
            s.traitEntity.pop();
            s.traitValue.pop();
        }

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(s.filterType, s.traitEntity, s.traitValue)
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
        value = TraitFilterComponentStorage.layout().entityIdToStruct[entity];
    }

    /**
     * Returns the native values for this component
     *
     * @param entity Entity to get value for
     * @return filterType Operation to perform for this filter
     * @return traitEntity Trait to check filter against
     * @return traitValue The value of the trait to filter
     */
    function getValue(
        uint256 entity
    )
        external
        view
        virtual
        returns (
            uint256[] memory filterType,
            uint256[] memory traitEntity,
            int256[] memory traitValue
        )
    {
        if (has(entity)) {
            Layout memory s = TraitFilterComponentStorage
                .layout()
                .entityIdToStruct[entity];
            (filterType, traitEntity, traitValue) = abi.decode(
                _getEncodedValues(s),
                (uint256[], uint256[], int256[])
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
        Layout storage s = TraitFilterComponentStorage
            .layout()
            .entityIdToStruct[entity];

        // ABI Encode all fields of the struct and add to values array
        values = new bytes[](3);
        values[0] = abi.encode(s.filterType);
        values[1] = abi.encode(s.traitEntity);
        values[2] = abi.encode(s.traitValue);
    }

    /**
     * Returns the bytes value for this component
     *
     * @param entity Entity to get value for
     */
    function getBytes(
        uint256 entity
    ) external view returns (bytes memory value) {
        Layout memory s = TraitFilterComponentStorage.layout().entityIdToStruct[
            entity
        ];
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
        Layout memory s = TraitFilterComponentStorage.layout().entityIdToStruct[
            entity
        ];
        (s.filterType, s.traitEntity, s.traitValue) = abi.decode(
            value,
            (uint256[], uint256[], int256[])
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
        delete TraitFilterComponentStorage.layout().entityIdToStruct[entity];
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
            delete TraitFilterComponentStorage.layout().entityIdToStruct[
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
        Layout storage s = TraitFilterComponentStorage
            .layout()
            .entityIdToStruct[entity];

        s.filterType = value.filterType;
        s.traitEntity = value.traitEntity;
        s.traitValue = value.traitValue;
    }

    function _setValue(uint256 entity, Layout memory value) internal {
        _setValueToStorage(entity, value);

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(value.filterType, value.traitEntity, value.traitValue)
        );
    }

    function _getEncodedValues(
        Layout memory value
    ) internal pure returns (bytes memory) {
        return
            abi.encode(value.filterType, value.traitEntity, value.traitValue);
    }
}
