// SPDX-License-Identifier: MIT
// Auto-generated using Mage CLI codegen (v1) - DO NOT EDIT

pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseStorageComponentV2, IBaseStorageComponentV2} from "../../core/components/BaseStorageComponentV2.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.pvpsummarycomponent.v1")
);

struct Layout {
    uint256[] lootGrantedToRecord;
    int256 trophyChange;
    uint256 battleOutcome;
    uint32 battleTimestamp;
    address opponentAddress;
    string ipfsUrl;
}

library PvpSummaryComponentStorage {
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
 * @title PvpSummaryComponent
 * @dev Store the summary of a PvP battle
 */
contract PvpSummaryComponent is BaseStorageComponentV2 {
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

        // The loot granted to the user for the battle
        keys[0] = "loot_granted_to_record";
        values[0] = TypesLibrary.SchemaValue.UINT256_ARRAY;

        // The trophies gained or lost by the user as a result of the battle
        keys[1] = "trophy_change";
        values[1] = TypesLibrary.SchemaValue.INT256;

        // The outcome of the battle
        keys[2] = "battle_outcome";
        values[2] = TypesLibrary.SchemaValue.UINT256;

        // The timestamp of the battle
        keys[3] = "battle_timestamp";
        values[3] = TypesLibrary.SchemaValue.UINT32;

        // The address of the opponent
        keys[4] = "opponent_address";
        values[4] = TypesLibrary.SchemaValue.ADDRESS;

        // IPFS URL of the battle summary
        keys[5] = "ipfs_url";
        values[5] = TypesLibrary.SchemaValue.STRING;
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
     * @param lootGrantedToRecord The loot granted to the user for the battle
     * @param trophyChange The trophies gained or lost by the user as a result of the battle
     * @param battleOutcome The outcome of the battle
     * @param battleTimestamp The timestamp of the battle
     * @param opponentAddress The address of the opponent
     * @param ipfsUrl IPFS URL of the battle summary
     */
    function setValue(
        uint256 entity,
        uint256[] memory lootGrantedToRecord,
        int256 trophyChange,
        uint256 battleOutcome,
        uint32 battleTimestamp,
        address opponentAddress,
        string calldata ipfsUrl
    ) external virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _setValue(
            entity,
            Layout(
                lootGrantedToRecord,
                trophyChange,
                battleOutcome,
                battleTimestamp,
                opponentAddress,
                ipfsUrl
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
        value = PvpSummaryComponentStorage.layout().entityIdToStruct[entity];
    }

    /**
     * Returns the native values for this component
     *
     * @param entity Entity to get value for
     * @return lootGrantedToRecord The loot granted to the user for the battle
     * @return trophyChange The trophies gained or lost by the user as a result of the battle
     * @return battleOutcome The outcome of the battle
     * @return battleTimestamp The timestamp of the battle
     * @return opponentAddress The address of the opponent
     * @return ipfsUrl IPFS URL of the battle summary
     */
    function getValue(
        uint256 entity
    )
        external
        view
        virtual
        returns (
            uint256[] memory lootGrantedToRecord,
            int256 trophyChange,
            uint256 battleOutcome,
            uint32 battleTimestamp,
            address opponentAddress,
            string memory ipfsUrl
        )
    {
        if (has(entity)) {
            Layout memory s = PvpSummaryComponentStorage
                .layout()
                .entityIdToStruct[entity];
            (
                lootGrantedToRecord,
                trophyChange,
                battleOutcome,
                battleTimestamp,
                opponentAddress,
                ipfsUrl
            ) = abi.decode(
                _getEncodedValues(s),
                (uint256[], int256, uint256, uint32, address, string)
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
        Layout storage s = PvpSummaryComponentStorage.layout().entityIdToStruct[
            entity
        ];

        // ABI Encode all fields of the struct and add to values array
        values = new bytes[](6);
        values[0] = abi.encode(s.lootGrantedToRecord);
        values[1] = abi.encode(s.trophyChange);
        values[2] = abi.encode(s.battleOutcome);
        values[3] = abi.encode(s.battleTimestamp);
        values[4] = abi.encode(s.opponentAddress);
        values[5] = abi.encode(s.ipfsUrl);
    }

    /**
     * Returns the bytes value for this component
     *
     * @param entity Entity to get value for
     */
    function getBytes(
        uint256 entity
    ) external view returns (bytes memory value) {
        Layout memory s = PvpSummaryComponentStorage.layout().entityIdToStruct[
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
        Layout memory s = PvpSummaryComponentStorage.layout().entityIdToStruct[
            entity
        ];
        (
            s.lootGrantedToRecord,
            s.trophyChange,
            s.battleOutcome,
            s.battleTimestamp,
            s.opponentAddress,
            s.ipfsUrl
        ) = abi.decode(
            value,
            (uint256[], int256, uint256, uint32, address, string)
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
            Layout memory s = PvpSummaryComponentStorage
                .layout()
                .entityIdToStruct[entities[i]];
            (
                s.lootGrantedToRecord,
                s.trophyChange,
                s.battleOutcome,
                s.battleTimestamp,
                s.opponentAddress,
                s.ipfsUrl
            ) = abi.decode(
                values[i],
                (uint256[], int256, uint256, uint32, address, string)
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
        delete PvpSummaryComponentStorage.layout().entityIdToStruct[entity];
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
            delete PvpSummaryComponentStorage.layout().entityIdToStruct[
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
        Layout storage s = PvpSummaryComponentStorage.layout().entityIdToStruct[
            entity
        ];

        s.lootGrantedToRecord = value.lootGrantedToRecord;
        s.trophyChange = value.trophyChange;
        s.battleOutcome = value.battleOutcome;
        s.battleTimestamp = value.battleTimestamp;
        s.opponentAddress = value.opponentAddress;
        s.ipfsUrl = value.ipfsUrl;
    }

    function _setValue(uint256 entity, Layout memory value) internal {
        _setValueToStorage(entity, value);

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(
                value.lootGrantedToRecord,
                value.trophyChange,
                value.battleOutcome,
                value.battleTimestamp,
                value.opponentAddress,
                value.ipfsUrl
            )
        );
    }

    function _getEncodedValues(
        Layout memory value
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                value.lootGrantedToRecord,
                value.trophyChange,
                value.battleOutcome,
                value.battleTimestamp,
                value.opponentAddress,
                value.ipfsUrl
            );
    }
}
