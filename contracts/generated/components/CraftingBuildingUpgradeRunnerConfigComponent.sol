// SPDX-License-Identifier: MIT
// Auto-generated using Mage CLI codegen (v1) - DO NOT EDIT

pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseStorageComponentV2, IBaseStorageComponentV2} from "../../core/components/BaseStorageComponentV2.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";

uint256 constant ID = uint256(
    keccak256(
        "game.piratenation.craftingbuildingupgraderunnerconfigcomponent.v1"
    )
);

struct Layout {
    uint256 nextLevelEntity;
    uint256 currentLevelEntity;
}

library CraftingBuildingUpgradeRunnerConfigComponentStorage {
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
 * @title CraftingBuildingUpgradeRunnerConfigComponent
 * @dev This component defines rules for a Crafting Building Upgrade runner.
 */
contract CraftingBuildingUpgradeRunnerConfigComponent is
    BaseStorageComponentV2
{
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

        // The next level of the crafting building that can be upgraded to
        keys[0] = "next_level_entity";
        values[0] = TypesLibrary.SchemaValue.UINT256;

        // The current level of the crafting building required for upgrade
        keys[1] = "current_level_entity";
        values[1] = TypesLibrary.SchemaValue.UINT256;
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
     * @param nextLevelEntity The next level of the crafting building that can be upgraded to
     * @param currentLevelEntity The current level of the crafting building required for upgrade
     */
    function setValue(
        uint256 entity,
        uint256 nextLevelEntity,
        uint256 currentLevelEntity
    ) external virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _setValue(entity, Layout(nextLevelEntity, currentLevelEntity));
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
        value = CraftingBuildingUpgradeRunnerConfigComponentStorage
            .layout()
            .entityIdToStruct[entity];
    }

    /**
     * Returns the native values for this component
     *
     * @param entity Entity to get value for
     * @return nextLevelEntity The next level of the crafting building that can be upgraded to
     * @return currentLevelEntity The current level of the crafting building required for upgrade
     */
    function getValue(
        uint256 entity
    )
        external
        view
        virtual
        returns (uint256 nextLevelEntity, uint256 currentLevelEntity)
    {
        if (has(entity)) {
            Layout
                memory s = CraftingBuildingUpgradeRunnerConfigComponentStorage
                    .layout()
                    .entityIdToStruct[entity];
            (nextLevelEntity, currentLevelEntity) = abi.decode(
                _getEncodedValues(s),
                (uint256, uint256)
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
        Layout storage s = CraftingBuildingUpgradeRunnerConfigComponentStorage
            .layout()
            .entityIdToStruct[entity];

        // ABI Encode all fields of the struct and add to values array
        values = new bytes[](2);
        values[0] = abi.encode(s.nextLevelEntity);
        values[1] = abi.encode(s.currentLevelEntity);
    }

    /**
     * Returns the bytes value for this component
     *
     * @param entity Entity to get value for
     */
    function getBytes(
        uint256 entity
    ) external view returns (bytes memory value) {
        Layout memory s = CraftingBuildingUpgradeRunnerConfigComponentStorage
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
        Layout memory s = CraftingBuildingUpgradeRunnerConfigComponentStorage
            .layout()
            .entityIdToStruct[entity];
        (s.nextLevelEntity, s.currentLevelEntity) = abi.decode(
            value,
            (uint256, uint256)
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
            Layout
                memory s = CraftingBuildingUpgradeRunnerConfigComponentStorage
                    .layout()
                    .entityIdToStruct[entities[i]];
            (s.nextLevelEntity, s.currentLevelEntity) = abi.decode(
                values[i],
                (uint256, uint256)
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
        delete CraftingBuildingUpgradeRunnerConfigComponentStorage
            .layout()
            .entityIdToStruct[entity];
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
            delete CraftingBuildingUpgradeRunnerConfigComponentStorage
                .layout()
                .entityIdToStruct[entities[i]];
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
        Layout storage s = CraftingBuildingUpgradeRunnerConfigComponentStorage
            .layout()
            .entityIdToStruct[entity];

        s.nextLevelEntity = value.nextLevelEntity;
        s.currentLevelEntity = value.currentLevelEntity;
    }

    function _setValue(uint256 entity, Layout memory value) internal {
        _setValueToStorage(entity, value);

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(value.nextLevelEntity, value.currentLevelEntity)
        );
    }

    function _getEncodedValues(
        Layout memory value
    ) internal pure returns (bytes memory) {
        return abi.encode(value.nextLevelEntity, value.currentLevelEntity);
    }
}
