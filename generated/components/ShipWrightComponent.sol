// SPDX-License-Identifier: MIT
// Auto-generated using Mage CLI codegen (v1) - DO NOT EDIT

pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseStorageComponentV2, IBaseStorageComponentV2} from "../../core/components/BaseStorageComponentV2.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.shipwrightcomponent.v1")
);

struct Layout {
    uint32 repairCooldownSeconds;
    uint32 planSwapCooldownSeconds;
    uint32 mergeCooldownSeconds;
    uint8 mergeMaxLevel;
}

library ShipWrightComponentStorage {
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
 * @title ShipWrightComponent
 * @dev Define settings for a shipwright
 */
contract ShipWrightComponent is BaseStorageComponentV2 {
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
        keys = new string[](4);
        values = new TypesLibrary.SchemaValue[](4);

        // Cooldown time in seconds for ship repair
        keys[0] = "repair_cooldown_seconds";
        values[0] = TypesLibrary.SchemaValue.UINT32;

        // Cooldown time in seconds for ship plan swap
        keys[1] = "plan_swap_cooldown_seconds";
        values[1] = TypesLibrary.SchemaValue.UINT32;

        // Cooldown time in seconds for ship merge
        keys[2] = "merge_cooldown_seconds";
        values[2] = TypesLibrary.SchemaValue.UINT32;

        // Maximum level for ship merge
        keys[3] = "merge_max_level";
        values[3] = TypesLibrary.SchemaValue.UINT8;
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
     * @param repairCooldownSeconds Cooldown time in seconds for ship repair
     * @param planSwapCooldownSeconds Cooldown time in seconds for ship plan swap
     * @param mergeCooldownSeconds Cooldown time in seconds for ship merge
     * @param mergeMaxLevel Maximum level for ship merge
     */
    function setValue(
        uint256 entity,
        uint32 repairCooldownSeconds,
        uint32 planSwapCooldownSeconds,
        uint32 mergeCooldownSeconds,
        uint8 mergeMaxLevel
    ) external virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _setValue(
            entity,
            Layout(
                repairCooldownSeconds,
                planSwapCooldownSeconds,
                mergeCooldownSeconds,
                mergeMaxLevel
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
        value = ShipWrightComponentStorage.layout().entityIdToStruct[entity];
    }

    /**
     * Returns the native values for this component
     *
     * @param entity Entity to get value for
     * @return repairCooldownSeconds Cooldown time in seconds for ship repair
     * @return planSwapCooldownSeconds Cooldown time in seconds for ship plan swap
     * @return mergeCooldownSeconds Cooldown time in seconds for ship merge
     * @return mergeMaxLevel Maximum level for ship merge
     */
    function getValue(
        uint256 entity
    )
        external
        view
        virtual
        returns (
            uint32 repairCooldownSeconds,
            uint32 planSwapCooldownSeconds,
            uint32 mergeCooldownSeconds,
            uint8 mergeMaxLevel
        )
    {
        if (has(entity)) {
            Layout memory s = ShipWrightComponentStorage
                .layout()
                .entityIdToStruct[entity];
            (
                repairCooldownSeconds,
                planSwapCooldownSeconds,
                mergeCooldownSeconds,
                mergeMaxLevel
            ) = abi.decode(
                _getEncodedValues(s),
                (uint32, uint32, uint32, uint8)
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
        Layout storage s = ShipWrightComponentStorage.layout().entityIdToStruct[
            entity
        ];

        // ABI Encode all fields of the struct and add to values array
        values = new bytes[](4);
        values[0] = abi.encode(s.repairCooldownSeconds);
        values[1] = abi.encode(s.planSwapCooldownSeconds);
        values[2] = abi.encode(s.mergeCooldownSeconds);
        values[3] = abi.encode(s.mergeMaxLevel);
    }

    /**
     * Returns the bytes value for this component
     *
     * @param entity Entity to get value for
     */
    function getBytes(
        uint256 entity
    ) external view returns (bytes memory value) {
        Layout memory s = ShipWrightComponentStorage.layout().entityIdToStruct[
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
        Layout memory s = ShipWrightComponentStorage.layout().entityIdToStruct[
            entity
        ];
        (
            s.repairCooldownSeconds,
            s.planSwapCooldownSeconds,
            s.mergeCooldownSeconds,
            s.mergeMaxLevel
        ) = abi.decode(value, (uint32, uint32, uint32, uint8));
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
        delete ShipWrightComponentStorage.layout().entityIdToStruct[entity];
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
            delete ShipWrightComponentStorage.layout().entityIdToStruct[
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
        Layout storage s = ShipWrightComponentStorage.layout().entityIdToStruct[
            entity
        ];

        s.repairCooldownSeconds = value.repairCooldownSeconds;
        s.planSwapCooldownSeconds = value.planSwapCooldownSeconds;
        s.mergeCooldownSeconds = value.mergeCooldownSeconds;
        s.mergeMaxLevel = value.mergeMaxLevel;
    }

    function _setValue(uint256 entity, Layout memory value) internal {
        _setValueToStorage(entity, value);

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(
                value.repairCooldownSeconds,
                value.planSwapCooldownSeconds,
                value.mergeCooldownSeconds,
                value.mergeMaxLevel
            )
        );
    }

    function _getEncodedValues(
        Layout memory value
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                value.repairCooldownSeconds,
                value.planSwapCooldownSeconds,
                value.mergeCooldownSeconds,
                value.mergeMaxLevel
            );
    }
}
