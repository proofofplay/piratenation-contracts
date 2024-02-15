// SPDX-License-Identifier: MIT
// Auto-generated using Mage CLI codegen (v1) - DO NOT EDIT

pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseStorageComponentV2, IBaseStorageComponentV2} from "../../core/components/BaseStorageComponentV2.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.transforminstancecomponent.v1")
);

struct Layout {
    uint256 transformEntity;
    address account;
    uint32 startTime;
    uint16 count;
    uint16 numSuccess;
    uint8 status;
    bool needsVrf;
}

library TransformInstanceComponentStorage {
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
 * @title TransformInstanceComponent
 * @dev This component is used to track a transform instance
 */
contract TransformInstanceComponent is BaseStorageComponentV2 {
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

        // Entity of the transform that was undertaken
        keys[0] = "transform_entity";
        values[0] = TypesLibrary.SchemaValue.UINT256;

        // User wallet address
        keys[1] = "account";
        values[1] = TypesLibrary.SchemaValue.ADDRESS;

        // When the transform was started
        keys[2] = "start_time";
        values[2] = TypesLibrary.SchemaValue.UINT32;

        // Number of times to perform this transform
        keys[3] = "count";
        values[3] = TypesLibrary.SchemaValue.UINT16;

        // Number of successful transforms
        keys[4] = "num_success";
        values[4] = TypesLibrary.SchemaValue.UINT16;

        // The status of the transform
        keys[5] = "status";
        values[5] = TypesLibrary.SchemaValue.UINT8;

        // Whether this transform needs a random number to complete
        keys[6] = "needs_vrf";
        values[6] = TypesLibrary.SchemaValue.BOOL;
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
     * @param transformEntity Entity of the transform that was undertaken
     * @param account User wallet address
     * @param startTime When the transform was started
     * @param count Number of times to perform this transform
     * @param numSuccess Number of successful transforms
     * @param status The status of the transform
     * @param needsVrf Whether this transform needs a random number to complete
     */
    function setValue(
        uint256 entity,
        uint256 transformEntity,
        address account,
        uint32 startTime,
        uint16 count,
        uint16 numSuccess,
        uint8 status,
        bool needsVrf
    ) external virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _setValue(
            entity,
            Layout(
                transformEntity,
                account,
                startTime,
                count,
                numSuccess,
                status,
                needsVrf
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
        value = TransformInstanceComponentStorage.layout().entityIdToStruct[
            entity
        ];
    }

    /**
     * Returns the native values for this component
     *
     * @param entity Entity to get value for
     * @return transformEntity Entity of the transform that was undertaken
     * @return account User wallet address
     * @return startTime When the transform was started
     * @return count Number of times to perform this transform
     * @return numSuccess Number of successful transforms
     * @return status The status of the transform
     * @return needsVrf Whether this transform needs a random number to complete
     */
    function getValue(
        uint256 entity
    )
        external
        view
        virtual
        returns (
            uint256 transformEntity,
            address account,
            uint32 startTime,
            uint16 count,
            uint16 numSuccess,
            uint8 status,
            bool needsVrf
        )
    {
        if (has(entity)) {
            Layout memory s = TransformInstanceComponentStorage
                .layout()
                .entityIdToStruct[entity];
            (
                transformEntity,
                account,
                startTime,
                count,
                numSuccess,
                status,
                needsVrf
            ) = abi.decode(
                _getEncodedValues(s),
                (uint256, address, uint32, uint16, uint16, uint8, bool)
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
        Layout storage s = TransformInstanceComponentStorage
            .layout()
            .entityIdToStruct[entity];

        // ABI Encode all fields of the struct and add to values array
        values = new bytes[](7);
        values[0] = abi.encode(s.transformEntity);
        values[1] = abi.encode(s.account);
        values[2] = abi.encode(s.startTime);
        values[3] = abi.encode(s.count);
        values[4] = abi.encode(s.numSuccess);
        values[5] = abi.encode(s.status);
        values[6] = abi.encode(s.needsVrf);
    }

    /**
     * Returns the bytes value for this component
     *
     * @param entity Entity to get value for
     */
    function getBytes(
        uint256 entity
    ) external view returns (bytes memory value) {
        Layout memory s = TransformInstanceComponentStorage
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
        Layout memory s = TransformInstanceComponentStorage
            .layout()
            .entityIdToStruct[entity];
        (
            s.transformEntity,
            s.account,
            s.startTime,
            s.count,
            s.numSuccess,
            s.status,
            s.needsVrf
        ) = abi.decode(
            value,
            (uint256, address, uint32, uint16, uint16, uint8, bool)
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
        delete TransformInstanceComponentStorage.layout().entityIdToStruct[
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
            delete TransformInstanceComponentStorage.layout().entityIdToStruct[
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
        Layout storage s = TransformInstanceComponentStorage
            .layout()
            .entityIdToStruct[entity];

        s.transformEntity = value.transformEntity;
        s.account = value.account;
        s.startTime = value.startTime;
        s.count = value.count;
        s.numSuccess = value.numSuccess;
        s.status = value.status;
        s.needsVrf = value.needsVrf;
    }

    function _setValue(uint256 entity, Layout memory value) internal {
        _setValueToStorage(entity, value);

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(
                value.transformEntity,
                value.account,
                value.startTime,
                value.count,
                value.numSuccess,
                value.status,
                value.needsVrf
            )
        );
    }

    function _getEncodedValues(
        Layout memory value
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                value.transformEntity,
                value.account,
                value.startTime,
                value.count,
                value.numSuccess,
                value.status,
                value.needsVrf
            );
    }
}
