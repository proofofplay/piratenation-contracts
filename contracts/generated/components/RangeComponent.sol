// SPDX-License-Identifier: MIT
// Auto-generated using Mage CLI codegen (v1) - DO NOT EDIT

pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseStorageComponentV2, IBaseStorageComponentV2} from "../../core/components/BaseStorageComponentV2.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.rangecomponent.v1"));

struct Layout {
    uint128 lowerBound;
    uint128 upperBound;
}

library RangeComponentStorage {
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
 * @title RangeComponent
 * @dev Specifiy a range for an entity
 */
contract RangeComponent is BaseStorageComponentV2 {
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

        // Lower bound of the range
        keys[0] = "lower_bound";
        values[0] = TypesLibrary.SchemaValue.UINT128;

        // Upper bound of the range
        keys[1] = "upper_bound";
        values[1] = TypesLibrary.SchemaValue.UINT128;
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
     * @param lowerBound Lower bound of the range
     * @param upperBound Upper bound of the range
     */
    function setValue(
        uint256 entity,
        uint128 lowerBound,
        uint128 upperBound
    ) external virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _setValue(entity, Layout(lowerBound, upperBound));
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
        value = RangeComponentStorage.layout().entityIdToStruct[entity];
    }

    /**
     * Returns the native values for this component
     *
     * @param entity Entity to get value for
     * @return lowerBound Lower bound of the range
     * @return upperBound Upper bound of the range
     */
    function getValue(
        uint256 entity
    ) external view virtual returns (uint128 lowerBound, uint128 upperBound) {
        if (has(entity)) {
            Layout memory s = RangeComponentStorage.layout().entityIdToStruct[
                entity
            ];
            (lowerBound, upperBound) = abi.decode(
                _getEncodedValues(s),
                (uint128, uint128)
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
        Layout storage s = RangeComponentStorage.layout().entityIdToStruct[
            entity
        ];

        // ABI Encode all fields of the struct and add to values array
        values = new bytes[](2);
        values[0] = abi.encode(s.lowerBound);
        values[1] = abi.encode(s.upperBound);
    }

    /**
     * Returns the bytes value for this component
     *
     * @param entity Entity to get value for
     */
    function getBytes(
        uint256 entity
    ) external view returns (bytes memory value) {
        Layout memory s = RangeComponentStorage.layout().entityIdToStruct[
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
        Layout memory s = RangeComponentStorage.layout().entityIdToStruct[
            entity
        ];
        (s.lowerBound, s.upperBound) = abi.decode(value, (uint128, uint128));
        _setValueToStorage(entity, s);

        // ABI Encode all native types of the struct
        _emitSetBytes(entity, value);
    }

    /**
     * Sets bytes data in batch format
     *
     * @param entities Entities to set value for
     * @param values Bytes values to set for the given entities
     */
    function batchSetBytes(
        uint256[] calldata entities,
        bytes[] calldata values
    ) external onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        if (entities.length != values.length) {
            revert InvalidBatchData(entities.length, values.length);
        }
        for (uint256 i = 0; i < entities.length; i++) {
            Layout memory s = RangeComponentStorage.layout().entityIdToStruct[
                entities[i]
            ];
            (s.lowerBound, s.upperBound) = abi.decode(
                values[i],
                (uint128, uint128)
            );
            _setValueToStorage(entities[i], s);
        }
        // ABI Encode all native types of the struct
        _emitBatchSetBytes(entities, values);
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
        delete RangeComponentStorage.layout().entityIdToStruct[entity];
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
            delete RangeComponentStorage.layout().entityIdToStruct[entities[i]];
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
        Layout storage s = RangeComponentStorage.layout().entityIdToStruct[
            entity
        ];

        s.lowerBound = value.lowerBound;
        s.upperBound = value.upperBound;
    }

    function _setValue(uint256 entity, Layout memory value) internal {
        _setValueToStorage(entity, value);

        // ABI Encode all native types of the struct
        _emitSetBytes(entity, abi.encode(value.lowerBound, value.upperBound));
    }

    function _getEncodedValues(
        Layout memory value
    ) internal pure returns (bytes memory) {
        return abi.encode(value.lowerBound, value.upperBound);
    }
}
