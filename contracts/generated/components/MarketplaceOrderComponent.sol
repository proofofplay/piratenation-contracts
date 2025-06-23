// SPDX-License-Identifier: MIT
// Auto-generated using Mage CLI codegen (v1) - DO NOT EDIT

pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseStorageComponentV2, IBaseStorageComponentV2} from "../../core/components/BaseStorageComponentV2.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.marketplaceordercomponent.v1")
);

struct Layout {
    uint256 listingId;
    uint256[] assetIds;
    uint256[] quantitiesFilled;
    uint256 orderTimestamp;
    address taker;
}

library MarketplaceOrderComponentStorage {
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
 * @title MarketplaceOrderComponent
 * @dev Order data for a marketplace order
 */
contract MarketplaceOrderComponent is BaseStorageComponentV2 {
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

        // The ID of the marketplace listing being purchased for this order
        keys[0] = "listing_id";
        values[0] = TypesLibrary.SchemaValue.UINT256;

        // The asset IDs being purchased
        keys[1] = "asset_ids";
        values[1] = TypesLibrary.SchemaValue.UINT256_ARRAY;

        // The quantities filled
        keys[2] = "quantities_filled";
        values[2] = TypesLibrary.SchemaValue.UINT256_ARRAY;

        // The timestamp of the order
        keys[3] = "order_timestamp";
        values[3] = TypesLibrary.SchemaValue.UINT256;

        // The address of the taker
        keys[4] = "taker";
        values[4] = TypesLibrary.SchemaValue.ADDRESS;
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
     * @param listingId The ID of the marketplace listing being purchased for this order
     * @param assetIds The asset IDs being purchased
     * @param quantitiesFilled The quantities filled
     * @param orderTimestamp The timestamp of the order
     * @param taker The address of the taker
     */
    function setValue(
        uint256 entity,
        uint256 listingId,
        uint256[] memory assetIds,
        uint256[] memory quantitiesFilled,
        uint256 orderTimestamp,
        address taker
    ) external virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _setValue(
            entity,
            Layout(listingId, assetIds, quantitiesFilled, orderTimestamp, taker)
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
        value = MarketplaceOrderComponentStorage.layout().entityIdToStruct[
            entity
        ];
    }

    /**
     * Returns the native values for this component
     *
     * @param entity Entity to get value for
     * @return listingId The ID of the marketplace listing being purchased for this order
     * @return assetIds The asset IDs being purchased
     * @return quantitiesFilled The quantities filled
     * @return orderTimestamp The timestamp of the order
     * @return taker The address of the taker
     */
    function getValue(
        uint256 entity
    )
        external
        view
        virtual
        returns (
            uint256 listingId,
            uint256[] memory assetIds,
            uint256[] memory quantitiesFilled,
            uint256 orderTimestamp,
            address taker
        )
    {
        if (has(entity)) {
            Layout memory s = MarketplaceOrderComponentStorage
                .layout()
                .entityIdToStruct[entity];
            (listingId, assetIds, quantitiesFilled, orderTimestamp, taker) = abi
                .decode(
                    _getEncodedValues(s),
                    (uint256, uint256[], uint256[], uint256, address)
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
        Layout storage s = MarketplaceOrderComponentStorage
            .layout()
            .entityIdToStruct[entity];

        // ABI Encode all fields of the struct and add to values array
        values = new bytes[](5);
        values[0] = abi.encode(s.listingId);
        values[1] = abi.encode(s.assetIds);
        values[2] = abi.encode(s.quantitiesFilled);
        values[3] = abi.encode(s.orderTimestamp);
        values[4] = abi.encode(s.taker);
    }

    /**
     * Returns the bytes value for this component
     *
     * @param entity Entity to get value for
     */
    function getBytes(
        uint256 entity
    ) external view returns (bytes memory value) {
        Layout memory s = MarketplaceOrderComponentStorage
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
        Layout memory s = MarketplaceOrderComponentStorage
            .layout()
            .entityIdToStruct[entity];
        (
            s.listingId,
            s.assetIds,
            s.quantitiesFilled,
            s.orderTimestamp,
            s.taker
        ) = abi.decode(
            value,
            (uint256, uint256[], uint256[], uint256, address)
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
            Layout memory s = MarketplaceOrderComponentStorage
                .layout()
                .entityIdToStruct[entities[i]];
            (
                s.listingId,
                s.assetIds,
                s.quantitiesFilled,
                s.orderTimestamp,
                s.taker
            ) = abi.decode(
                values[i],
                (uint256, uint256[], uint256[], uint256, address)
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
        delete MarketplaceOrderComponentStorage.layout().entityIdToStruct[
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
            delete MarketplaceOrderComponentStorage.layout().entityIdToStruct[
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
        Layout storage s = MarketplaceOrderComponentStorage
            .layout()
            .entityIdToStruct[entity];

        s.listingId = value.listingId;
        s.assetIds = value.assetIds;
        s.quantitiesFilled = value.quantitiesFilled;
        s.orderTimestamp = value.orderTimestamp;
        s.taker = value.taker;
    }

    function _setValue(uint256 entity, Layout memory value) internal {
        _setValueToStorage(entity, value);

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(
                value.listingId,
                value.assetIds,
                value.quantitiesFilled,
                value.orderTimestamp,
                value.taker
            )
        );
    }

    function _getEncodedValues(
        Layout memory value
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                value.listingId,
                value.assetIds,
                value.quantitiesFilled,
                value.orderTimestamp,
                value.taker
            );
    }
}
