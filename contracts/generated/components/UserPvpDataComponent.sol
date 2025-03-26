// SPDX-License-Identifier: MIT
// Auto-generated using Mage CLI codegen (v1) - DO NOT EDIT

pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseStorageComponentV2, IBaseStorageComponentV2} from "../../core/components/BaseStorageComponentV2.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.userpvpdatacomponent.v1")
);

struct Layout {
    int256 matchmakingRating;
    int256 matchmakingRatingDeviation;
    int256 matchmakingRatingVolatility;
    uint32 matchmakingRatingLastUpdate;
    uint64 winCount;
    uint64 lossCount;
}

library UserPvpDataComponentStorage {
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
 * @title UserPvpDataComponent
 * @dev Track the values for a user&#39;s PvP data
 */
contract UserPvpDataComponent is BaseStorageComponentV2 {
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

        // The user&#39;s matchmaking rating
        keys[0] = "matchmaking_rating";
        values[0] = TypesLibrary.SchemaValue.INT256;

        // The user&#39;s matchmaking rating deviation
        keys[1] = "matchmaking_rating_deviation";
        values[1] = TypesLibrary.SchemaValue.INT256;

        // The user&#39;s matchmaking rating volatility
        keys[2] = "matchmaking_rating_volatility";
        values[2] = TypesLibrary.SchemaValue.INT256;

        // The timestamp of the user&#39;s last matchmaking rating update
        keys[3] = "matchmaking_rating_last_update";
        values[3] = TypesLibrary.SchemaValue.UINT32;

        // The user&#39;s win count
        keys[4] = "win_count";
        values[4] = TypesLibrary.SchemaValue.UINT64;

        // The user&#39;s loss count
        keys[5] = "loss_count";
        values[5] = TypesLibrary.SchemaValue.UINT64;
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
     * @param matchmakingRating The user&#39;s matchmaking rating
     * @param matchmakingRatingDeviation The user&#39;s matchmaking rating deviation
     * @param matchmakingRatingVolatility The user&#39;s matchmaking rating volatility
     * @param matchmakingRatingLastUpdate The timestamp of the user&#39;s last matchmaking rating update
     * @param winCount The user&#39;s win count
     * @param lossCount The user&#39;s loss count
     */
    function setValue(
        uint256 entity,
        int256 matchmakingRating,
        int256 matchmakingRatingDeviation,
        int256 matchmakingRatingVolatility,
        uint32 matchmakingRatingLastUpdate,
        uint64 winCount,
        uint64 lossCount
    ) external virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _setValue(
            entity,
            Layout(
                matchmakingRating,
                matchmakingRatingDeviation,
                matchmakingRatingVolatility,
                matchmakingRatingLastUpdate,
                winCount,
                lossCount
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
        value = UserPvpDataComponentStorage.layout().entityIdToStruct[entity];
    }

    /**
     * Returns the native values for this component
     *
     * @param entity Entity to get value for
     * @return matchmakingRating The user&#39;s matchmaking rating
     * @return matchmakingRatingDeviation The user&#39;s matchmaking rating deviation
     * @return matchmakingRatingVolatility The user&#39;s matchmaking rating volatility
     * @return matchmakingRatingLastUpdate The timestamp of the user&#39;s last matchmaking rating update
     * @return winCount The user&#39;s win count
     * @return lossCount The user&#39;s loss count
     */
    function getValue(
        uint256 entity
    )
        external
        view
        virtual
        returns (
            int256 matchmakingRating,
            int256 matchmakingRatingDeviation,
            int256 matchmakingRatingVolatility,
            uint32 matchmakingRatingLastUpdate,
            uint64 winCount,
            uint64 lossCount
        )
    {
        if (has(entity)) {
            Layout memory s = UserPvpDataComponentStorage
                .layout()
                .entityIdToStruct[entity];
            (
                matchmakingRating,
                matchmakingRatingDeviation,
                matchmakingRatingVolatility,
                matchmakingRatingLastUpdate,
                winCount,
                lossCount
            ) = abi.decode(
                _getEncodedValues(s),
                (int256, int256, int256, uint32, uint64, uint64)
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
        Layout storage s = UserPvpDataComponentStorage
            .layout()
            .entityIdToStruct[entity];

        // ABI Encode all fields of the struct and add to values array
        values = new bytes[](6);
        values[0] = abi.encode(s.matchmakingRating);
        values[1] = abi.encode(s.matchmakingRatingDeviation);
        values[2] = abi.encode(s.matchmakingRatingVolatility);
        values[3] = abi.encode(s.matchmakingRatingLastUpdate);
        values[4] = abi.encode(s.winCount);
        values[5] = abi.encode(s.lossCount);
    }

    /**
     * Returns the bytes value for this component
     *
     * @param entity Entity to get value for
     */
    function getBytes(
        uint256 entity
    ) external view returns (bytes memory value) {
        Layout memory s = UserPvpDataComponentStorage.layout().entityIdToStruct[
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
        Layout memory s = UserPvpDataComponentStorage.layout().entityIdToStruct[
            entity
        ];
        (
            s.matchmakingRating,
            s.matchmakingRatingDeviation,
            s.matchmakingRatingVolatility,
            s.matchmakingRatingLastUpdate,
            s.winCount,
            s.lossCount
        ) = abi.decode(value, (int256, int256, int256, uint32, uint64, uint64));
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
            Layout memory s = UserPvpDataComponentStorage
                .layout()
                .entityIdToStruct[entities[i]];
            (
                s.matchmakingRating,
                s.matchmakingRatingDeviation,
                s.matchmakingRatingVolatility,
                s.matchmakingRatingLastUpdate,
                s.winCount,
                s.lossCount
            ) = abi.decode(
                values[i],
                (int256, int256, int256, uint32, uint64, uint64)
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
        delete UserPvpDataComponentStorage.layout().entityIdToStruct[entity];
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
            delete UserPvpDataComponentStorage.layout().entityIdToStruct[
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
        Layout storage s = UserPvpDataComponentStorage
            .layout()
            .entityIdToStruct[entity];

        s.matchmakingRating = value.matchmakingRating;
        s.matchmakingRatingDeviation = value.matchmakingRatingDeviation;
        s.matchmakingRatingVolatility = value.matchmakingRatingVolatility;
        s.matchmakingRatingLastUpdate = value.matchmakingRatingLastUpdate;
        s.winCount = value.winCount;
        s.lossCount = value.lossCount;
    }

    function _setValue(uint256 entity, Layout memory value) internal {
        _setValueToStorage(entity, value);

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(
                value.matchmakingRating,
                value.matchmakingRatingDeviation,
                value.matchmakingRatingVolatility,
                value.matchmakingRatingLastUpdate,
                value.winCount,
                value.lossCount
            )
        );
    }

    function _getEncodedValues(
        Layout memory value
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                value.matchmakingRating,
                value.matchmakingRatingDeviation,
                value.matchmakingRatingVolatility,
                value.matchmakingRatingLastUpdate,
                value.winCount,
                value.lossCount
            );
    }
}
