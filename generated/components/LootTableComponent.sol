// SPDX-License-Identifier: MIT
// Auto-generated using Mage CLI codegen (v1) - DO NOT EDIT

pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseStorageComponentV2, IBaseStorageComponentV2} from "../../core/components/BaseStorageComponentV2.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.loottablecomponent.v4")
);

struct Layout {
    uint256[] lootEntities;
    uint256[] weights;
    uint256[] maxSupply;
}

library LootTableComponentStorage {
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
 * @title LootTableComponent
 * @dev Defines a LootTable that allows for random loot drops. Each row is a set of loot that can be granted with different weight probabilities.
 */
contract LootTableComponent is BaseStorageComponentV2 {
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

        // Entity thats contains the set of loot to grant for this row in the table
        keys[0] = "loot_entities";
        values[0] = TypesLibrary.SchemaValue.UINT256_ARRAY;

        // Probability weight of each loot table row
        keys[1] = "weights";
        values[1] = TypesLibrary.SchemaValue.UINT256_ARRAY;

        // Max supply of each loot table row. 0 for infinite supply
        keys[2] = "max_supply";
        values[2] = TypesLibrary.SchemaValue.UINT256_ARRAY;
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
     * @param lootEntities Entity thats contains the set of loot to grant for this row in the table
     * @param weights Probability weight of each loot table row
     * @param maxSupply Max supply of each loot table row. 0 for infinite supply
     */
    function setValue(
        uint256 entity,
        uint256[] memory lootEntities,
        uint256[] memory weights,
        uint256[] memory maxSupply
    ) external virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _setValue(entity, Layout(lootEntities, weights, maxSupply));
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
        Layout storage s = LootTableComponentStorage.layout().entityIdToStruct[
            entity
        ];
        for (uint256 i = 0; i < values.lootEntities.length; i++) {
            s.lootEntities.push(values.lootEntities[i]);
            s.weights.push(values.weights[i]);
            s.maxSupply.push(values.maxSupply[i]);
        }

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(s.lootEntities, s.weights, s.maxSupply)
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
        Layout storage s = LootTableComponentStorage.layout().entityIdToStruct[
            entity
        ];

        for (uint256 i = 0; i < indexes.length; i++) {
            uint256 indexToRemove = indexes[i];
            // Get the last index
            uint256 lastIndexInArray = s.lootEntities.length - 1;
            // Move the last value to the index to pop
            if (indexToRemove != lastIndexInArray) {
                s.lootEntities[indexToRemove] = s.lootEntities[
                    lastIndexInArray
                ];
                s.weights[indexToRemove] = s.weights[lastIndexInArray];
                s.maxSupply[indexToRemove] = s.maxSupply[lastIndexInArray];
            }
            // Pop the last value
            s.lootEntities.pop();
            s.weights.pop();
            s.maxSupply.pop();
        }

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(s.lootEntities, s.weights, s.maxSupply)
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
        value = LootTableComponentStorage.layout().entityIdToStruct[entity];
    }

    /**
     * Returns the native values for this component
     *
     * @param entity Entity to get value for
     * @return lootEntities Entity thats contains the set of loot to grant for this row in the table
     * @return weights Probability weight of each loot table row
     * @return maxSupply Max supply of each loot table row. 0 for infinite supply
     */
    function getValue(
        uint256 entity
    )
        external
        view
        virtual
        returns (
            uint256[] memory lootEntities,
            uint256[] memory weights,
            uint256[] memory maxSupply
        )
    {
        if (has(entity)) {
            Layout memory s = LootTableComponentStorage
                .layout()
                .entityIdToStruct[entity];
            (lootEntities, weights, maxSupply) = abi.decode(
                _getEncodedValues(s),
                (uint256[], uint256[], uint256[])
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
        Layout storage s = LootTableComponentStorage.layout().entityIdToStruct[
            entity
        ];

        // ABI Encode all fields of the struct and add to values array
        values = new bytes[](3);
        values[0] = abi.encode(s.lootEntities);
        values[1] = abi.encode(s.weights);
        values[2] = abi.encode(s.maxSupply);
    }

    /**
     * Returns the bytes value for this component
     *
     * @param entity Entity to get value for
     */
    function getBytes(
        uint256 entity
    ) external view returns (bytes memory value) {
        Layout memory s = LootTableComponentStorage.layout().entityIdToStruct[
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
        Layout memory s = LootTableComponentStorage.layout().entityIdToStruct[
            entity
        ];
        (s.lootEntities, s.weights, s.maxSupply) = abi.decode(
            value,
            (uint256[], uint256[], uint256[])
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
        delete LootTableComponentStorage.layout().entityIdToStruct[entity];
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
            delete LootTableComponentStorage.layout().entityIdToStruct[
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
        Layout storage s = LootTableComponentStorage.layout().entityIdToStruct[
            entity
        ];

        s.lootEntities = value.lootEntities;
        s.weights = value.weights;
        s.maxSupply = value.maxSupply;
    }

    function _setValue(uint256 entity, Layout memory value) internal {
        _setValueToStorage(entity, value);

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(value.lootEntities, value.weights, value.maxSupply)
        );
    }

    function _getEncodedValues(
        Layout memory value
    ) internal pure returns (bytes memory) {
        return abi.encode(value.lootEntities, value.weights, value.maxSupply);
    }
}
