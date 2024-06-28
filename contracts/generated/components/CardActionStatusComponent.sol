// SPDX-License-Identifier: MIT
// Auto-generated using Mage CLI codegen (v1) - DO NOT EDIT

pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseStorageComponentV2, IBaseStorageComponentV2} from "../../core/components/BaseStorageComponentV2.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.cardactionstatuscomponent.v1")
);

struct Layout {
    uint16 durationValue;
    uint8 startCondition;
    uint8 durationCondition;
    uint8 statusClearCondition;
    uint8 statusEffectType;
}

library CardActionStatusComponentStorage {
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
 * @title CardActionStatusComponent
 * @dev Card Action Status Component is a component that defines data for a status effect of a specific action and its duration conditions.
 */
contract CardActionStatusComponent is BaseStorageComponentV2 {
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

        // Effect duration value (usually in turns)
        keys[0] = "duration_value";
        values[0] = TypesLibrary.SchemaValue.UINT16;

        // Effect start condition defined as enum: instant, start_round end_round
        keys[1] = "start_condition";
        values[1] = TypesLibrary.SchemaValue.UINT8;

        // If an effect is applied what is the condition that decrements its duration
        keys[2] = "duration_condition";
        values[2] = TypesLibrary.SchemaValue.UINT8;

        // Condition at which this effects completely clears
        keys[3] = "status_clear_condition";
        values[3] = TypesLibrary.SchemaValue.UINT8;

        // Condition at which this effects completely clears
        keys[4] = "status_effect_type";
        values[4] = TypesLibrary.SchemaValue.UINT8;
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
     * @param durationValue Effect duration value (usually in turns)
     * @param startCondition Effect start condition defined as enum: instant, start_round end_round
     * @param durationCondition If an effect is applied what is the condition that decrements its duration
     * @param statusClearCondition Condition at which this effects completely clears
     * @param statusEffectType Condition at which this effects completely clears
     */
    function setValue(
        uint256 entity,
        uint16 durationValue,
        uint8 startCondition,
        uint8 durationCondition,
        uint8 statusClearCondition,
        uint8 statusEffectType
    ) external virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _setValue(
            entity,
            Layout(
                durationValue,
                startCondition,
                durationCondition,
                statusClearCondition,
                statusEffectType
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
        value = CardActionStatusComponentStorage.layout().entityIdToStruct[
            entity
        ];
    }

    /**
     * Returns the native values for this component
     *
     * @param entity Entity to get value for
     * @return durationValue Effect duration value (usually in turns)
     * @return startCondition Effect start condition defined as enum: instant, start_round end_round
     * @return durationCondition If an effect is applied what is the condition that decrements its duration
     * @return statusClearCondition Condition at which this effects completely clears
     * @return statusEffectType Condition at which this effects completely clears
     */
    function getValue(
        uint256 entity
    )
        external
        view
        virtual
        returns (
            uint16 durationValue,
            uint8 startCondition,
            uint8 durationCondition,
            uint8 statusClearCondition,
            uint8 statusEffectType
        )
    {
        if (has(entity)) {
            Layout memory s = CardActionStatusComponentStorage
                .layout()
                .entityIdToStruct[entity];
            (
                durationValue,
                startCondition,
                durationCondition,
                statusClearCondition,
                statusEffectType
            ) = abi.decode(
                _getEncodedValues(s),
                (uint16, uint8, uint8, uint8, uint8)
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
        Layout storage s = CardActionStatusComponentStorage
            .layout()
            .entityIdToStruct[entity];

        // ABI Encode all fields of the struct and add to values array
        values = new bytes[](5);
        values[0] = abi.encode(s.durationValue);
        values[1] = abi.encode(s.startCondition);
        values[2] = abi.encode(s.durationCondition);
        values[3] = abi.encode(s.statusClearCondition);
        values[4] = abi.encode(s.statusEffectType);
    }

    /**
     * Returns the bytes value for this component
     *
     * @param entity Entity to get value for
     */
    function getBytes(
        uint256 entity
    ) external view returns (bytes memory value) {
        Layout memory s = CardActionStatusComponentStorage
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
        Layout memory s = CardActionStatusComponentStorage
            .layout()
            .entityIdToStruct[entity];
        (
            s.durationValue,
            s.startCondition,
            s.durationCondition,
            s.statusClearCondition,
            s.statusEffectType
        ) = abi.decode(value, (uint16, uint8, uint8, uint8, uint8));
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
            Layout memory s = CardActionStatusComponentStorage
                .layout()
                .entityIdToStruct[entities[i]];
            (
                s.durationValue,
                s.startCondition,
                s.durationCondition,
                s.statusClearCondition,
                s.statusEffectType
            ) = abi.decode(values[i], (uint16, uint8, uint8, uint8, uint8));
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
        delete CardActionStatusComponentStorage.layout().entityIdToStruct[
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
            delete CardActionStatusComponentStorage.layout().entityIdToStruct[
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
        Layout storage s = CardActionStatusComponentStorage
            .layout()
            .entityIdToStruct[entity];

        s.durationValue = value.durationValue;
        s.startCondition = value.startCondition;
        s.durationCondition = value.durationCondition;
        s.statusClearCondition = value.statusClearCondition;
        s.statusEffectType = value.statusEffectType;
    }

    function _setValue(uint256 entity, Layout memory value) internal {
        _setValueToStorage(entity, value);

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(
                value.durationValue,
                value.startCondition,
                value.durationCondition,
                value.statusClearCondition,
                value.statusEffectType
            )
        );
    }

    function _getEncodedValues(
        Layout memory value
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                value.durationValue,
                value.startCondition,
                value.durationCondition,
                value.statusClearCondition,
                value.statusEffectType
            );
    }
}
