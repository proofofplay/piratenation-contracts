// SPDX-License-Identifier: MIT
// Auto-generated using Mage CLI codegen (v1) - DO NOT EDIT

pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseStorageComponentV2, IBaseStorageComponentV2} from "../../core/components/BaseStorageComponentV2.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.teststackdepthcomponent")
);

struct Layout {
    string stringValueA;
    string stringValueB;
    string stringValueC;
    string stringValueD;
    string stringValueE;
}

library FakeStackDepthComponentStorage {
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
 * @title FakeStackDepthComponent
 * @dev Test Component for Stack Depth
 */
contract FakeStackDepthComponent is BaseStorageComponentV2 {
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
        keys = new string[](5);
        values = new TypesLibrary.SchemaValue[](5);

        // A string value
        keys[0] = "string_value_a";
        values[0] = TypesLibrary.SchemaValue.STRING;

        // A string value
        keys[1] = "string_value_b";
        values[1] = TypesLibrary.SchemaValue.STRING;

        // A string value
        keys[2] = "string_value_c";
        values[2] = TypesLibrary.SchemaValue.STRING;

        // A string value
        keys[3] = "string_value_d";
        values[3] = TypesLibrary.SchemaValue.STRING;

        // A string value
        keys[4] = "string_value_e";
        values[4] = TypesLibrary.SchemaValue.STRING;
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
     * @param stringValueA A string value
     * @param stringValueB A string value
     * @param stringValueC A string value
     * @param stringValueD A string value
     * @param stringValueE A string value
     */
    function setValue(
        uint256 entity,
        string calldata stringValueA,
        string calldata stringValueB,
        string calldata stringValueC,
        string calldata stringValueD,
        string calldata stringValueE
    ) external virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _setValue(
            entity,
            Layout(
                stringValueA,
                stringValueB,
                stringValueC,
                stringValueD,
                stringValueE
            )
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
        value = FakeStackDepthComponentStorage.layout().entityIdToStruct[
            entity
        ];
    }

    /**
     * Returns the native values for this component
     *
     * @param entity Entity to get value for
     * @return stringValueA A string value
     * @return stringValueB A string value
     * @return stringValueC A string value
     * @return stringValueD A string value
     * @return stringValueE A string value
     */
    function getValue(
        uint256 entity
    )
        external
        view
        virtual
        returns (
            string memory stringValueA,
            string memory stringValueB,
            string memory stringValueC,
            string memory stringValueD,
            string memory stringValueE
        )
    {
        if (has(entity)) {
            Layout memory s = FakeStackDepthComponentStorage
                .layout()
                .entityIdToStruct[entity];
            (
                stringValueA,
                stringValueB,
                stringValueC,
                stringValueD,
                stringValueE
            ) = abi.decode(
                _getEncodedValues(s),
                (string, string, string, string, string)
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
        Layout storage s = FakeStackDepthComponentStorage
            .layout()
            .entityIdToStruct[entity];

        // ABI Encode all fields of the struct and add to values array
        values = new bytes[](5);
        values[0] = abi.encode(s.stringValueA);
        values[1] = abi.encode(s.stringValueB);
        values[2] = abi.encode(s.stringValueC);
        values[3] = abi.encode(s.stringValueD);
        values[4] = abi.encode(s.stringValueE);
    }

    /**
     * Returns the bytes value for this component
     *
     * @param entity Entity to get value for
     */
    function getBytes(
        uint256 entity
    ) external view returns (bytes memory value) {
        Layout memory s = FakeStackDepthComponentStorage
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
        Layout memory s = FakeStackDepthComponentStorage
            .layout()
            .entityIdToStruct[entity];
        (
            s.stringValueA,
            s.stringValueB,
            s.stringValueC,
            s.stringValueD,
            s.stringValueE
        ) = abi.decode(value, (string, string, string, string, string));
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
            Layout memory s = FakeStackDepthComponentStorage
                .layout()
                .entityIdToStruct[entities[i]];
            (
                s.stringValueA,
                s.stringValueB,
                s.stringValueC,
                s.stringValueD,
                s.stringValueE
            ) = abi.decode(values[i], (string, string, string, string, string));
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
        delete FakeStackDepthComponentStorage.layout().entityIdToStruct[entity];
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
            delete FakeStackDepthComponentStorage.layout().entityIdToStruct[
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
        Layout storage s = FakeStackDepthComponentStorage
            .layout()
            .entityIdToStruct[entity];

        s.stringValueA = value.stringValueA;
        s.stringValueB = value.stringValueB;
        s.stringValueC = value.stringValueC;
        s.stringValueD = value.stringValueD;
        s.stringValueE = value.stringValueE;
    }

    function _setValue(uint256 entity, Layout memory value) internal {
        _setValueToStorage(entity, value);

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(
                value.stringValueA,
                value.stringValueB,
                value.stringValueC,
                value.stringValueD,
                value.stringValueE
            )
        );
    }

    function _getEncodedValues(
        Layout memory value
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                value.stringValueA,
                value.stringValueB,
                value.stringValueC,
                value.stringValueD,
                value.stringValueE
            );
    }
}