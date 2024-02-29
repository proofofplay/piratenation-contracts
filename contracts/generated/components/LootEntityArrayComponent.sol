// SPDX-License-Identifier: MIT
// Auto-generated using Mage CLI codegen (v1) - DO NOT EDIT

pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseStorageComponentV2, IBaseStorageComponentV2} from "../../core/components/BaseStorageComponentV2.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.lootentityarraycomponent.v1")
);

struct Layout {
    uint32[] lootType;
    uint256[] lootEntity;
    uint256[] amount;
}

library LootEntityArrayComponentStorage {
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
 * @title LootEntityArrayComponent
 * @dev Array of loot that can be granted to the user. Loot can be a NFT, currency, loot table, etc.
 */
contract LootEntityArrayComponent is BaseStorageComponentV2 {
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

        // Type of fulfillment (ERC721, ERC1155, ERC20, LOOT_TABLE)
        keys[0] = "loot_type";
        values[0] = TypesLibrary.SchemaValue.UINT32_ARRAY;

        // Entity to grant (NFT, token contract, loot table, etc.)
        keys[1] = "loot_entity";
        values[1] = TypesLibrary.SchemaValue.UINT256_ARRAY;

        // Amount of loot to grant
        keys[2] = "amount";
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
     * @param lootType Type of fulfillment (ERC721, ERC1155, ERC20, LOOT_TABLE)
     * @param lootEntity Entity to grant (NFT, token contract, loot table, etc.)
     * @param amount Amount of loot to grant
     */
    function setValue(
        uint256 entity,
        uint32[] memory lootType,
        uint256[] memory lootEntity,
        uint256[] memory amount
    ) external virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _setValue(entity, Layout(lootType, lootEntity, amount));
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
        Layout storage s = LootEntityArrayComponentStorage
            .layout()
            .entityIdToStruct[entity];
        for (uint256 i = 0; i < values.lootType.length; i++) {
            s.lootType.push(values.lootType[i]);
            s.lootEntity.push(values.lootEntity[i]);
            s.amount.push(values.amount[i]);
        }

        // ABI Encode all native types of the struct
        _emitSetBytes(entity, abi.encode(s.lootType, s.lootEntity, s.amount));
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
        Layout storage s = LootEntityArrayComponentStorage
            .layout()
            .entityIdToStruct[entity];

        // Get the last index
        uint256 lastIndexInArray = s.lootType.length - 1;

        // Move the last value to the index to pop
        if (index != lastIndexInArray) {
            s.lootType[index] = s.lootType[lastIndexInArray];
            s.lootEntity[index] = s.lootEntity[lastIndexInArray];
            s.amount[index] = s.amount[lastIndexInArray];
        }

        // Pop the last value
        s.lootType.pop();
        s.lootEntity.pop();
        s.amount.pop();

        // ABI Encode all native types of the struct
        _emitSetBytes(entity, abi.encode(s.lootType, s.lootEntity, s.amount));
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
        value = LootEntityArrayComponentStorage.layout().entityIdToStruct[
            entity
        ];
    }

    /**
     * Returns the native values for this component
     *
     * @param entity Entity to get value for
     * @return lootType Type of fulfillment (ERC721, ERC1155, ERC20, LOOT_TABLE)
     * @return lootEntity Entity to grant (NFT, token contract, loot table, etc.)
     * @return amount Amount of loot to grant
     */
    function getValue(
        uint256 entity
    )
        external
        view
        virtual
        returns (
            uint32[] memory lootType,
            uint256[] memory lootEntity,
            uint256[] memory amount
        )
    {
        if (has(entity)) {
            Layout memory s = LootEntityArrayComponentStorage
                .layout()
                .entityIdToStruct[entity];
            (lootType, lootEntity, amount) = abi.decode(
                _getEncodedValues(s),
                (uint32[], uint256[], uint256[])
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
        Layout storage s = LootEntityArrayComponentStorage
            .layout()
            .entityIdToStruct[entity];

        // ABI Encode all fields of the struct and add to values array
        values = new bytes[](3);
        values[0] = abi.encode(s.lootType);
        values[1] = abi.encode(s.lootEntity);
        values[2] = abi.encode(s.amount);
    }

    /**
     * Returns the bytes value for this component
     *
     * @param entity Entity to get value for
     */
    function getBytes(
        uint256 entity
    ) external view returns (bytes memory value) {
        Layout memory s = LootEntityArrayComponentStorage
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
        Layout memory s = LootEntityArrayComponentStorage
            .layout()
            .entityIdToStruct[entity];
        (s.lootType, s.lootEntity, s.amount) = abi.decode(
            value,
            (uint32[], uint256[], uint256[])
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
            Layout memory s = LootEntityArrayComponentStorage
                .layout()
                .entityIdToStruct[entities[i]];
            (s.lootType, s.lootEntity, s.amount) = abi.decode(
                values[i],
                (uint32[], uint256[], uint256[])
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
        delete LootEntityArrayComponentStorage.layout().entityIdToStruct[
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
            delete LootEntityArrayComponentStorage.layout().entityIdToStruct[
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
        Layout storage s = LootEntityArrayComponentStorage
            .layout()
            .entityIdToStruct[entity];

        s.lootType = value.lootType;
        s.lootEntity = value.lootEntity;
        s.amount = value.amount;
    }

    function _setValue(uint256 entity, Layout memory value) internal {
        _setValueToStorage(entity, value);

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(value.lootType, value.lootEntity, value.amount)
        );
    }

    function _getEncodedValues(
        Layout memory value
    ) internal pure returns (bytes memory) {
        return abi.encode(value.lootType, value.lootEntity, value.amount);
    }
}
