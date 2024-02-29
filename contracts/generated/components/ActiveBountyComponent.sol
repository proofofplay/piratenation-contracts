// SPDX-License-Identifier: MIT
// Auto-generated using Mage CLI codegen (v1) - DO NOT EDIT

pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseStorageComponentV2, IBaseStorageComponentV2} from "../../core/components/BaseStorageComponentV2.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.activebountycomponent")
);

struct Layout {
    uint32 status;
    address account;
    uint32 startTime;
    uint256 bountyId;
    uint256 groupId;
    uint256[] entityInputs;
}

library ActiveBountyComponentStorage {
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
 * @title ActiveBountyComponent
 * @dev This component is used to mark the active bounty for a player.
 */
contract ActiveBountyComponent is BaseStorageComponentV2 {
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
        keys = new string[](6);
        values = new TypesLibrary.SchemaValue[](6);

        // The status of the bounty (uint256 rep of the enum).
        keys[0] = "status";
        values[0] = TypesLibrary.SchemaValue.UINT32;

        // User wallet address
        keys[1] = "account";
        values[1] = TypesLibrary.SchemaValue.ADDRESS;

        // Active bounty start time
        keys[2] = "start_time";
        values[2] = TypesLibrary.SchemaValue.UINT32;

        // Bounty id
        keys[3] = "bounty_id";
        values[3] = TypesLibrary.SchemaValue.UINT256;

        // Group id
        keys[4] = "group_id";
        values[4] = TypesLibrary.SchemaValue.UINT256;

        // Entity inputs used for this bounty
        keys[5] = "entity_inputs";
        values[5] = TypesLibrary.SchemaValue.UINT256_ARRAY;
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
     * @param status The status of the bounty (uint256 rep of the enum).
     * @param account User wallet address
     * @param startTime Active bounty start time
     * @param bountyId Bounty id
     * @param groupId Group id
     * @param entityInputs Entity inputs used for this bounty
     */
    function setValue(
        uint256 entity,
        uint32 status,
        address account,
        uint32 startTime,
        uint256 bountyId,
        uint256 groupId,
        uint256[] memory entityInputs
    ) external virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _setValue(
            entity,
            Layout(status, account, startTime, bountyId, groupId, entityInputs)
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
        value = ActiveBountyComponentStorage.layout().entityIdToStruct[entity];
    }

    /**
     * Returns the native values for this component
     *
     * @param entity Entity to get value for
     * @return status The status of the bounty (uint256 rep of the enum).
     * @return account User wallet address
     * @return startTime Active bounty start time
     * @return bountyId Bounty id
     * @return groupId Group id
     * @return entityInputs Entity inputs used for this bounty
     */
    function getValue(
        uint256 entity
    )
        external
        view
        virtual
        returns (
            uint32 status,
            address account,
            uint32 startTime,
            uint256 bountyId,
            uint256 groupId,
            uint256[] memory entityInputs
        )
    {
        if (has(entity)) {
            Layout memory s = ActiveBountyComponentStorage
                .layout()
                .entityIdToStruct[entity];
            (status, account, startTime, bountyId, groupId, entityInputs) = abi
                .decode(
                    _getEncodedValues(s),
                    (uint32, address, uint32, uint256, uint256, uint256[])
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
        Layout storage s = ActiveBountyComponentStorage
            .layout()
            .entityIdToStruct[entity];

        // ABI Encode all fields of the struct and add to values array
        values = new bytes[](6);
        values[0] = abi.encode(s.status);
        values[1] = abi.encode(s.account);
        values[2] = abi.encode(s.startTime);
        values[3] = abi.encode(s.bountyId);
        values[4] = abi.encode(s.groupId);
        values[5] = abi.encode(s.entityInputs);
    }

    /**
     * Returns the bytes value for this component
     *
     * @param entity Entity to get value for
     */
    function getBytes(
        uint256 entity
    ) external view returns (bytes memory value) {
        Layout memory s = ActiveBountyComponentStorage
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
        Layout memory s = ActiveBountyComponentStorage
            .layout()
            .entityIdToStruct[entity];
        (
            s.status,
            s.account,
            s.startTime,
            s.bountyId,
            s.groupId,
            s.entityInputs
        ) = abi.decode(
            value,
            (uint32, address, uint32, uint256, uint256, uint256[])
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
            Layout memory s = ActiveBountyComponentStorage
                .layout()
                .entityIdToStruct[entities[i]];
            (
                s.status,
                s.account,
                s.startTime,
                s.bountyId,
                s.groupId,
                s.entityInputs
            ) = abi.decode(
                values[i],
                (uint32, address, uint32, uint256, uint256, uint256[])
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
        delete ActiveBountyComponentStorage.layout().entityIdToStruct[entity];
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
            delete ActiveBountyComponentStorage.layout().entityIdToStruct[
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
        Layout storage s = ActiveBountyComponentStorage
            .layout()
            .entityIdToStruct[entity];

        s.status = value.status;
        s.account = value.account;
        s.startTime = value.startTime;
        s.bountyId = value.bountyId;
        s.groupId = value.groupId;
        s.entityInputs = value.entityInputs;
    }

    function _setValue(uint256 entity, Layout memory value) internal {
        _setValueToStorage(entity, value);

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(
                value.status,
                value.account,
                value.startTime,
                value.bountyId,
                value.groupId,
                value.entityInputs
            )
        );
    }

    function _getEncodedValues(
        Layout memory value
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                value.status,
                value.account,
                value.startTime,
                value.bountyId,
                value.groupId,
                value.entityInputs
            );
    }
}
