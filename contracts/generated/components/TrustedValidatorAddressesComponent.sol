// SPDX-License-Identifier: MIT
// Auto-generated using Mage CLI codegen (v1) - DO NOT EDIT

pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseStorageComponentV2, IBaseStorageComponentV2} from "../../core/components/BaseStorageComponentV2.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.trustedvalidatoraddressescomponent")
);

struct Layout {
    address[] serverPublicAddresses;
    string[] hosts;
    uint16[] ports;
    bool[] hasMultiplayerPirates;
    bool[] hasSsl;
}

library TrustedValidatorAddressesComponentStorage {
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
 * @title TrustedValidatorAddressesComponent
 * @dev A public list of trusted validators
 */
contract TrustedValidatorAddressesComponent is BaseStorageComponentV2 {
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

        // An array of public addresses of trusted validators
        keys[0] = "server_public_addresses";
        values[0] = TypesLibrary.SchemaValue.ADDRESS_ARRAY;

        // An array of domains of trusted validators
        keys[1] = "hosts";
        values[1] = TypesLibrary.SchemaValue.STRING_ARRAY;

        // An array of ports of trusted validators
        keys[2] = "ports";
        values[2] = TypesLibrary.SchemaValue.UINT16_ARRAY;

        // Test flags for experimental multiplayer features for validators
        keys[3] = "has_multiplayer_pirates";
        values[3] = TypesLibrary.SchemaValue.BOOL_ARRAY;

        // An array of flags for WSS protocol for trusted validators
        keys[4] = "has_ssl";
        values[4] = TypesLibrary.SchemaValue.BOOL_ARRAY;
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
     * @param serverPublicAddresses An array of public addresses of trusted validators
     * @param hosts An array of domains of trusted validators
     * @param ports An array of ports of trusted validators
     * @param hasMultiplayerPirates Test flags for experimental multiplayer features for validators
     * @param hasSsl An array of flags for WSS protocol for trusted validators
     */
    function setValue(
        uint256 entity,
        address[] memory serverPublicAddresses,
        string[] memory hosts,
        uint16[] memory ports,
        bool[] memory hasMultiplayerPirates,
        bool[] memory hasSsl
    ) external virtual onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _setValue(
            entity,
            Layout(
                serverPublicAddresses,
                hosts,
                ports,
                hasMultiplayerPirates,
                hasSsl
            )
        );
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
        Layout storage s = TrustedValidatorAddressesComponentStorage
            .layout()
            .entityIdToStruct[entity];
        for (uint256 i = 0; i < values.serverPublicAddresses.length; i++) {
            s.serverPublicAddresses.push(values.serverPublicAddresses[i]);
            s.hosts.push(values.hosts[i]);
            s.ports.push(values.ports[i]);
            s.hasMultiplayerPirates.push(values.hasMultiplayerPirates[i]);
            s.hasSsl.push(values.hasSsl[i]);
        }

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(
                s.serverPublicAddresses,
                s.hosts,
                s.ports,
                s.hasMultiplayerPirates,
                s.hasSsl
            )
        );
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
        Layout storage s = TrustedValidatorAddressesComponentStorage
            .layout()
            .entityIdToStruct[entity];

        // Get the last index
        uint256 lastIndexInArray = s.serverPublicAddresses.length - 1;

        // Move the last value to the index to pop
        if (index != lastIndexInArray) {
            s.serverPublicAddresses[index] = s.serverPublicAddresses[
                lastIndexInArray
            ];
            s.hosts[index] = s.hosts[lastIndexInArray];
            s.ports[index] = s.ports[lastIndexInArray];
            s.hasMultiplayerPirates[index] = s.hasMultiplayerPirates[
                lastIndexInArray
            ];
            s.hasSsl[index] = s.hasSsl[lastIndexInArray];
        }

        // Pop the last value
        s.serverPublicAddresses.pop();
        s.hosts.pop();
        s.ports.pop();
        s.hasMultiplayerPirates.pop();
        s.hasSsl.pop();

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(
                s.serverPublicAddresses,
                s.hosts,
                s.ports,
                s.hasMultiplayerPirates,
                s.hasSsl
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
        value = TrustedValidatorAddressesComponentStorage
            .layout()
            .entityIdToStruct[entity];
    }

    /**
     * Returns the native values for this component
     *
     * @param entity Entity to get value for
     * @return serverPublicAddresses An array of public addresses of trusted validators
     * @return hosts An array of domains of trusted validators
     * @return ports An array of ports of trusted validators
     * @return hasMultiplayerPirates Test flags for experimental multiplayer features for validators
     * @return hasSsl An array of flags for WSS protocol for trusted validators
     */
    function getValue(
        uint256 entity
    )
        external
        view
        virtual
        returns (
            address[] memory serverPublicAddresses,
            string[] memory hosts,
            uint16[] memory ports,
            bool[] memory hasMultiplayerPirates,
            bool[] memory hasSsl
        )
    {
        if (has(entity)) {
            Layout memory s = TrustedValidatorAddressesComponentStorage
                .layout()
                .entityIdToStruct[entity];
            (
                serverPublicAddresses,
                hosts,
                ports,
                hasMultiplayerPirates,
                hasSsl
            ) = abi.decode(
                _getEncodedValues(s),
                (address[], string[], uint16[], bool[], bool[])
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
        Layout storage s = TrustedValidatorAddressesComponentStorage
            .layout()
            .entityIdToStruct[entity];

        // ABI Encode all fields of the struct and add to values array
        values = new bytes[](5);
        values[0] = abi.encode(s.serverPublicAddresses);
        values[1] = abi.encode(s.hosts);
        values[2] = abi.encode(s.ports);
        values[3] = abi.encode(s.hasMultiplayerPirates);
        values[4] = abi.encode(s.hasSsl);
    }

    /**
     * Returns the bytes value for this component
     *
     * @param entity Entity to get value for
     */
    function getBytes(
        uint256 entity
    ) external view returns (bytes memory value) {
        Layout memory s = TrustedValidatorAddressesComponentStorage
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
        Layout memory s = TrustedValidatorAddressesComponentStorage
            .layout()
            .entityIdToStruct[entity];
        (
            s.serverPublicAddresses,
            s.hosts,
            s.ports,
            s.hasMultiplayerPirates,
            s.hasSsl
        ) = abi.decode(value, (address[], string[], uint16[], bool[], bool[]));
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
            Layout memory s = TrustedValidatorAddressesComponentStorage
                .layout()
                .entityIdToStruct[entities[i]];
            (
                s.serverPublicAddresses,
                s.hosts,
                s.ports,
                s.hasMultiplayerPirates,
                s.hasSsl
            ) = abi.decode(
                values[i],
                (address[], string[], uint16[], bool[], bool[])
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
        delete TrustedValidatorAddressesComponentStorage
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
            delete TrustedValidatorAddressesComponentStorage
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
        Layout storage s = TrustedValidatorAddressesComponentStorage
            .layout()
            .entityIdToStruct[entity];

        s.serverPublicAddresses = value.serverPublicAddresses;
        s.hosts = value.hosts;
        s.ports = value.ports;
        s.hasMultiplayerPirates = value.hasMultiplayerPirates;
        s.hasSsl = value.hasSsl;
    }

    function _setValue(uint256 entity, Layout memory value) internal {
        _setValueToStorage(entity, value);

        // ABI Encode all native types of the struct
        _emitSetBytes(
            entity,
            abi.encode(
                value.serverPublicAddresses,
                value.hosts,
                value.ports,
                value.hasMultiplayerPirates,
                value.hasSsl
            )
        );
    }

    function _getEncodedValues(
        Layout memory value
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                value.serverPublicAddresses,
                value.hosts,
                value.ports,
                value.hasMultiplayerPirates,
                value.hasSsl
            );
    }
}
