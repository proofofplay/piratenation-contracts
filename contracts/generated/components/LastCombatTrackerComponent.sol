// SPDX-License-Identifier: MIT
// Auto-generated using Mage CLI codegen (v1) - DO NOT EDIT

pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseStorageComponentV2, IBaseStorageComponentV2} from "../../core/components/BaseStorageComponentV2.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.lastcombattrackercomponent.v1")
);

struct Layout {
    uint256 transformInstanceEntity;
    uint256 pirateEntity;
    uint256 shipEntity;
    uint256 shipHealth;
    string[] cardsToPersist;
}

library LastCombatTrackerComponentStorage {
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
 * @title LastCombatTrackerComponent
 * @dev A component that tracks the last combat data
 */
contract LastCombatTrackerComponent is BaseStorageComponentV2 {
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

        // The transform instance entity that was used
        keys[0] = "transform_instance_entity";
        values[0] = TypesLibrary.SchemaValue.UINT256;

        // The pirate entity that was used
        keys[1] = "pirate_entity";
        values[1] = TypesLibrary.SchemaValue.UINT256;

        // The ship entity that was used
        keys[2] = "ship_entity";
        values[2] = TypesLibrary.SchemaValue.UINT256;

        // The health of the ship
        keys[3] = "ship_health";
        values[3] = TypesLibrary.SchemaValue.UINT256;

        // The cards to persist
        keys[4] = "cards_to_persist";
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
     * @param transformInstanceEntity The transform instance entity that was used
     * @param pirateEntity The pirate entity that was used
     * @param shipEntity The ship entity that was used
     * @param shipHealth The health of the ship
     * @param cardsToPersist The cards to persist
     */
    function setValue(
        uint256 entity,
        uint256 transformInstanceEntity,
        uint256 pirateEntity,
        uint256 shipEntity,
        uint256 shipHealth,
        string[] memory cardsToPersist
    ) external virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _setValue(
            entity,
            Layout(
                transformInstanceEntity,
                pirateEntity,
                shipEntity,
                shipHealth,
                cardsToPersist
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
        value = LastCombatTrackerComponentStorage.layout().entityIdToStruct[
            entity
        ];
    }

    /**
     * Returns the native values for this component
     *
     * @param entity Entity to get value for
     * @return transformInstanceEntity The transform instance entity that was used
     * @return pirateEntity The pirate entity that was used
     * @return shipEntity The ship entity that was used
     * @return shipHealth The health of the ship
     * @return cardsToPersist The cards to persist
     */
    function getValue(
        uint256 entity
    )
        external
        view
        virtual
        returns (
            uint256 transformInstanceEntity,
            uint256 pirateEntity,
            uint256 shipEntity,
            uint256 shipHealth,
            string[] memory cardsToPersist
        )
    {
        if (has(entity)) {
            Layout memory s = LastCombatTrackerComponentStorage
                .layout()
                .entityIdToStruct[entity];
            (
                transformInstanceEntity,
                pirateEntity,
                shipEntity,
                shipHealth,
                cardsToPersist
            ) = abi.decode(
                _getEncodedValues(s),
                (uint256, uint256, uint256, uint256, string[])
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
        Layout storage s = LastCombatTrackerComponentStorage
            .layout()
            .entityIdToStruct[entity];

        // ABI Encode all fields of the struct and add to values array
        values = new bytes[](5);
        values[0] = abi.encode(s.transformInstanceEntity);
        values[1] = abi.encode(s.pirateEntity);
        values[2] = abi.encode(s.shipEntity);
        values[3] = abi.encode(s.shipHealth);
        values[4] = abi.encode(s.cardsToPersist);
    }

    /**
     * Returns the bytes value for this component
     *
     * @param entity Entity to get value for
     */
    function getBytes(
        uint256 entity
    ) external view returns (bytes memory value) {
        Layout memory s = LastCombatTrackerComponentStorage
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
        Layout memory s = LastCombatTrackerComponentStorage
            .layout()
            .entityIdToStruct[entity];
        (
            s.transformInstanceEntity,
            s.pirateEntity,
            s.shipEntity,
            s.shipHealth,
            s.cardsToPersist
        ) = abi.decode(value, (uint256, uint256, uint256, uint256, string[]));
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
            Layout memory s = LastCombatTrackerComponentStorage
                .layout()
                .entityIdToStruct[entities[i]];
            (
                s.transformInstanceEntity,
                s.pirateEntity,
                s.shipEntity,
                s.shipHealth,
                s.cardsToPersist
            ) = abi.decode(
                values[i],
                (uint256, uint256, uint256, uint256, string[])
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
        delete LastCombatTrackerComponentStorage.layout().entityIdToStruct[
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
            delete LastCombatTrackerComponentStorage.layout().entityIdToStruct[
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
        Layout storage s = LastCombatTrackerComponentStorage
            .layout()
            .entityIdToStruct[entity];

        s.transformInstanceEntity = value.transformInstanceEntity;
        s.pirateEntity = value.pirateEntity;
        s.shipEntity = value.shipEntity;
        s.shipHealth = value.shipHealth;
        s.cardsToPersist = value.cardsToPersist;
    }

    function _setValue(uint256 entity, Layout memory value) internal {
        _setValueToStorage(entity, value);

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(
                value.transformInstanceEntity,
                value.pirateEntity,
                value.shipEntity,
                value.shipHealth,
                value.cardsToPersist
            )
        );
    }

    function _getEncodedValues(
        Layout memory value
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                value.transformInstanceEntity,
                value.pirateEntity,
                value.shipEntity,
                value.shipHealth,
                value.cardsToPersist
            );
    }
}
