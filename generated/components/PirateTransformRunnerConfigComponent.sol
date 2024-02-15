// SPDX-License-Identifier: MIT
// Auto-generated using Mage CLI codegen (v1) - DO NOT EDIT

pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseStorageComponentV2, IBaseStorageComponentV2} from "../../core/components/BaseStorageComponentV2.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.piratetransformrunnercomponent.v1")
);

struct Layout {
    uint128 energyRequired;
    uint16 minPirateLevel;
    uint16 maxPirateLevel;
    uint16 minPirateGeneration;
    uint16 maxPirateGeneration;
    uint16 baseSuccessProbability;
    uint32 successXp;
}

library PirateTransformRunnerConfigComponentStorage {
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
 * @title PirateTransformRunnerConfigComponent
 * @dev This component is used configure quests using the PirateTransformRunner. Requires that the first input is a pirate NFT.
 */
contract PirateTransformRunnerConfigComponent is BaseStorageComponentV2 {
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
        keys = new string[](7);
        values = new TypesLibrary.SchemaValue[](7);

        // How much energy is required for this transform
        keys[0] = "energy_required";
        values[0] = TypesLibrary.SchemaValue.UINT128;

        // Minimum required pirate level for this transform
        keys[1] = "min_pirate_level";
        values[1] = TypesLibrary.SchemaValue.UINT16;

        // Maxmimum allowable pirate level for this transform
        keys[2] = "max_pirate_level";
        values[2] = TypesLibrary.SchemaValue.UINT16;

        // Minimum required pirate generation for this transform
        keys[3] = "min_pirate_generation";
        values[3] = TypesLibrary.SchemaValue.UINT16;

        // Maximum allowable pirate generation for this transform
        keys[4] = "max_pirate_generation";
        values[4] = TypesLibrary.SchemaValue.UINT16;

        // Base probability of success for this transform
        keys[5] = "base_success_probability";
        values[5] = TypesLibrary.SchemaValue.UINT16;

        // Account XP reward for successful transform
        keys[6] = "success_xp";
        values[6] = TypesLibrary.SchemaValue.UINT32;
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
     * @param energyRequired How much energy is required for this transform
     * @param minPirateLevel Minimum required pirate level for this transform
     * @param maxPirateLevel Maxmimum allowable pirate level for this transform
     * @param minPirateGeneration Minimum required pirate generation for this transform
     * @param maxPirateGeneration Maximum allowable pirate generation for this transform
     * @param baseSuccessProbability Base probability of success for this transform
     * @param successXp Account XP reward for successful transform
     */
    function setValue(
        uint256 entity,
        uint128 energyRequired,
        uint16 minPirateLevel,
        uint16 maxPirateLevel,
        uint16 minPirateGeneration,
        uint16 maxPirateGeneration,
        uint16 baseSuccessProbability,
        uint32 successXp
    ) external virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _setValue(
            entity,
            Layout(
                energyRequired,
                minPirateLevel,
                maxPirateLevel,
                minPirateGeneration,
                maxPirateGeneration,
                baseSuccessProbability,
                successXp
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
        value = PirateTransformRunnerConfigComponentStorage
            .layout()
            .entityIdToStruct[entity];
    }

    /**
     * Returns the native values for this component
     *
     * @param entity Entity to get value for
     * @return energyRequired How much energy is required for this transform
     * @return minPirateLevel Minimum required pirate level for this transform
     * @return maxPirateLevel Maxmimum allowable pirate level for this transform
     * @return minPirateGeneration Minimum required pirate generation for this transform
     * @return maxPirateGeneration Maximum allowable pirate generation for this transform
     * @return baseSuccessProbability Base probability of success for this transform
     * @return successXp Account XP reward for successful transform
     */
    function getValue(
        uint256 entity
    )
        external
        view
        virtual
        returns (
            uint128 energyRequired,
            uint16 minPirateLevel,
            uint16 maxPirateLevel,
            uint16 minPirateGeneration,
            uint16 maxPirateGeneration,
            uint16 baseSuccessProbability,
            uint32 successXp
        )
    {
        if (has(entity)) {
            Layout memory s = PirateTransformRunnerConfigComponentStorage
                .layout()
                .entityIdToStruct[entity];
            (
                energyRequired,
                minPirateLevel,
                maxPirateLevel,
                minPirateGeneration,
                maxPirateGeneration,
                baseSuccessProbability,
                successXp
            ) = abi.decode(
                _getEncodedValues(s),
                (uint128, uint16, uint16, uint16, uint16, uint16, uint32)
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
        Layout storage s = PirateTransformRunnerConfigComponentStorage
            .layout()
            .entityIdToStruct[entity];

        // ABI Encode all fields of the struct and add to values array
        values = new bytes[](7);
        values[0] = abi.encode(s.energyRequired);
        values[1] = abi.encode(s.minPirateLevel);
        values[2] = abi.encode(s.maxPirateLevel);
        values[3] = abi.encode(s.minPirateGeneration);
        values[4] = abi.encode(s.maxPirateGeneration);
        values[5] = abi.encode(s.baseSuccessProbability);
        values[6] = abi.encode(s.successXp);
    }

    /**
     * Returns the bytes value for this component
     *
     * @param entity Entity to get value for
     */
    function getBytes(
        uint256 entity
    ) external view returns (bytes memory value) {
        Layout memory s = PirateTransformRunnerConfigComponentStorage
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
        Layout memory s = PirateTransformRunnerConfigComponentStorage
            .layout()
            .entityIdToStruct[entity];
        (
            s.energyRequired,
            s.minPirateLevel,
            s.maxPirateLevel,
            s.minPirateGeneration,
            s.maxPirateGeneration,
            s.baseSuccessProbability,
            s.successXp
        ) = abi.decode(
            value,
            (uint128, uint16, uint16, uint16, uint16, uint16, uint32)
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
        delete PirateTransformRunnerConfigComponentStorage
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
            delete PirateTransformRunnerConfigComponentStorage
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
        Layout storage s = PirateTransformRunnerConfigComponentStorage
            .layout()
            .entityIdToStruct[entity];

        s.energyRequired = value.energyRequired;
        s.minPirateLevel = value.minPirateLevel;
        s.maxPirateLevel = value.maxPirateLevel;
        s.minPirateGeneration = value.minPirateGeneration;
        s.maxPirateGeneration = value.maxPirateGeneration;
        s.baseSuccessProbability = value.baseSuccessProbability;
        s.successXp = value.successXp;
    }

    function _setValue(uint256 entity, Layout memory value) internal {
        _setValueToStorage(entity, value);

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(
                value.energyRequired,
                value.minPirateLevel,
                value.maxPirateLevel,
                value.minPirateGeneration,
                value.maxPirateGeneration,
                value.baseSuccessProbability,
                value.successXp
            )
        );
    }

    function _getEncodedValues(
        Layout memory value
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                value.energyRequired,
                value.minPirateLevel,
                value.maxPirateLevel,
                value.minPirateGeneration,
                value.maxPirateGeneration,
                value.baseSuccessProbability,
                value.successXp
            );
    }
}
