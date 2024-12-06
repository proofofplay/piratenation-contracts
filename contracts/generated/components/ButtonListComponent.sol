// SPDX-License-Identifier: MIT
// Auto-generated using Mage CLI codegen (v1) - DO NOT EDIT

pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseStorageComponentV2, IBaseStorageComponentV2} from "../../core/components/BaseStorageComponentV2.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.buttonlistcomponent")
);

struct Layout {
    string[] key;
    uint256[] buttonType;
    string[] buttonText;
    uint256[] buttonAction;
    string[] buttonActionParam;
}

library ButtonListComponentStorage {
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
 * @title ButtonListComponent
 * @dev A list of buttons to display
 */
contract ButtonListComponent is BaseStorageComponentV2 {
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

        // The key of the button to configure
        keys[0] = "key";
        values[0] = TypesLibrary.SchemaValue.STRING_ARRAY;

        // The type of button to display
        keys[1] = "button_type";
        values[1] = TypesLibrary.SchemaValue.UINT256_ARRAY;

        // The text to display on the button
        keys[2] = "button_text";
        values[2] = TypesLibrary.SchemaValue.STRING_ARRAY;

        // The entities to perform when the buttons are clicked
        keys[3] = "button_action";
        values[3] = TypesLibrary.SchemaValue.UINT256_ARRAY;

        // The parameter passed to the action when triggered
        keys[4] = "button_action_param";
        values[4] = TypesLibrary.SchemaValue.STRING_ARRAY;
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
     * @param key The key of the button to configure
     * @param buttonType The type of button to display
     * @param buttonText The text to display on the button
     * @param buttonAction The entities to perform when the buttons are clicked
     * @param buttonActionParam The parameter passed to the action when triggered
     */
    function setValue(
        uint256 entity,
        string[] memory key,
        uint256[] memory buttonType,
        string[] memory buttonText,
        uint256[] memory buttonAction,
        string[] memory buttonActionParam
    ) external virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _setValue(
            entity,
            Layout(key, buttonType, buttonText, buttonAction, buttonActionParam)
        );
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
        Layout storage s = ButtonListComponentStorage.layout().entityIdToStruct[
            entity
        ];
        for (uint256 i = 0; i < values.key.length; i++) {
            s.key.push(values.key[i]);
            s.buttonType.push(values.buttonType[i]);
            s.buttonText.push(values.buttonText[i]);
            s.buttonAction.push(values.buttonAction[i]);
            s.buttonActionParam.push(values.buttonActionParam[i]);
        }

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(
                s.key,
                s.buttonType,
                s.buttonText,
                s.buttonAction,
                s.buttonActionParam
            )
        );
    }

    /**
     * @dev Removes the value at a given index
     * @param entity Entity to get value for
     * @param index Index to remove
     */
    function removeValueAtIndex(
        uint256 entity,
        uint256 index
    ) public virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        Layout storage s = ButtonListComponentStorage.layout().entityIdToStruct[
            entity
        ];

        // Get the last index
        uint256 lastIndexInArray = s.key.length - 1;

        // Move the last value to the index to pop
        if (index != lastIndexInArray) {
            s.key[index] = s.key[lastIndexInArray];
            s.buttonType[index] = s.buttonType[lastIndexInArray];
            s.buttonText[index] = s.buttonText[lastIndexInArray];
            s.buttonAction[index] = s.buttonAction[lastIndexInArray];
            s.buttonActionParam[index] = s.buttonActionParam[lastIndexInArray];
        }

        // Pop the last value
        s.key.pop();
        s.buttonType.pop();
        s.buttonText.pop();
        s.buttonAction.pop();
        s.buttonActionParam.pop();

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(
                s.key,
                s.buttonType,
                s.buttonText,
                s.buttonAction,
                s.buttonActionParam
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
        value = ButtonListComponentStorage.layout().entityIdToStruct[entity];
    }

    /**
     * Returns the native values for this component
     *
     * @param entity Entity to get value for
     * @return key The key of the button to configure
     * @return buttonType The type of button to display
     * @return buttonText The text to display on the button
     * @return buttonAction The entities to perform when the buttons are clicked
     * @return buttonActionParam The parameter passed to the action when triggered
     */
    function getValue(
        uint256 entity
    )
        external
        view
        virtual
        returns (
            string[] memory key,
            uint256[] memory buttonType,
            string[] memory buttonText,
            uint256[] memory buttonAction,
            string[] memory buttonActionParam
        )
    {
        if (has(entity)) {
            Layout memory s = ButtonListComponentStorage
                .layout()
                .entityIdToStruct[entity];
            (key, buttonType, buttonText, buttonAction, buttonActionParam) = abi
                .decode(
                    _getEncodedValues(s),
                    (string[], uint256[], string[], uint256[], string[])
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
        Layout storage s = ButtonListComponentStorage.layout().entityIdToStruct[
            entity
        ];

        // ABI Encode all fields of the struct and add to values array
        values = new bytes[](5);
        values[0] = abi.encode(s.key);
        values[1] = abi.encode(s.buttonType);
        values[2] = abi.encode(s.buttonText);
        values[3] = abi.encode(s.buttonAction);
        values[4] = abi.encode(s.buttonActionParam);
    }

    /**
     * Returns the bytes value for this component
     *
     * @param entity Entity to get value for
     */
    function getBytes(
        uint256 entity
    ) external view returns (bytes memory value) {
        Layout memory s = ButtonListComponentStorage.layout().entityIdToStruct[
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
        Layout memory s = ButtonListComponentStorage.layout().entityIdToStruct[
            entity
        ];
        (
            s.key,
            s.buttonType,
            s.buttonText,
            s.buttonAction,
            s.buttonActionParam
        ) = abi.decode(
            value,
            (string[], uint256[], string[], uint256[], string[])
        );
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
            Layout memory s = ButtonListComponentStorage
                .layout()
                .entityIdToStruct[entities[i]];
            (
                s.key,
                s.buttonType,
                s.buttonText,
                s.buttonAction,
                s.buttonActionParam
            ) = abi.decode(
                values[i],
                (string[], uint256[], string[], uint256[], string[])
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
        delete ButtonListComponentStorage.layout().entityIdToStruct[entity];
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
            delete ButtonListComponentStorage.layout().entityIdToStruct[
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
        Layout storage s = ButtonListComponentStorage.layout().entityIdToStruct[
            entity
        ];

        s.key = value.key;
        s.buttonType = value.buttonType;
        s.buttonText = value.buttonText;
        s.buttonAction = value.buttonAction;
        s.buttonActionParam = value.buttonActionParam;
    }

    function _setValue(uint256 entity, Layout memory value) internal {
        _setValueToStorage(entity, value);

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(
                value.key,
                value.buttonType,
                value.buttonText,
                value.buttonAction,
                value.buttonActionParam
            )
        );
    }

    function _getEncodedValues(
        Layout memory value
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                value.key,
                value.buttonType,
                value.buttonText,
                value.buttonAction,
                value.buttonActionParam
            );
    }
}
