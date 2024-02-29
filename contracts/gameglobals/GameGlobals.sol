// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {GAME_LOGIC_CONTRACT_ROLE, MANAGER_ROLE} from "../Constants.sol";
import "../GameRegistryConsumerUpgradeable.sol";

import "./IGameGlobals.sol";

/** @title Holds static and dynamic globals */
contract GameGlobals is GameRegistryConsumerUpgradeable, IGameGlobals {
    /// @notice Meta data for each global
    mapping(uint256 => GlobalMetadata) private _globalMetadata;

    /// @notice Mapping of globalId to the boolean value for a global
    mapping(uint256 => bool) private _globalValueBool;

    /// @notice Mapping of globalId to the uint256 value for a global
    mapping(uint256 => uint256) private _globalValueUint256;

    /// @notice Mapping of globalId to the int256 value for a global
    mapping(uint256 => int256) private _globalValueInt256;

    /// @notice Mapping of globalId to the uint256 array value for a global
    mapping(uint256 => uint256[]) private _globalValueUint256Array;

    /// @notice Mapping of globalId to the int256 array value for a global
    mapping(uint256 => int256[]) private _globalValueInt256Array;

    /// @notice Mapping of globalId to the string value for a global
    mapping(uint256 => string) private _globalValueString;

    /// @notice Mapping of globalId to the string array value for a global
    mapping(uint256 => string[]) private _globalValueStringArray;

    /** EVENTS **/

    /// @notice Emitted when a given global's metadata has changed
    event GlobalMetadataSet(uint256 indexed globalId);

    /// @notice Emitted when globals have been updated.
    event GlobalUpdated(uint256 indexed globalId);

    /** ERRORS **/

    /// @notice GlobalMetadata has already been initialized
    error MetadataAlreadyInitialized(uint256 globalId);

    /// @notice GlobalMetadata must have a name
    error MustSetGlobalName(uint256 globalId);

    /// @notice GlobalMetadata must have a dataType set
    error MustSetGlobalDataType(uint256 globalId);

    /// @notice globalIds and values arrays must be same length and have at least one element
    error InvalidArrayLengths();

    /// @notice Data type mismatch
    error DataTypeMismatch(
        uint256 globalId,
        GlobalDataType expected,
        GlobalDataType actual
    );

    /// @notice Metadata not initialized for global
    error MetadataNotInitialized(uint256 globalId);

    /** SETUP **/

    /** Initializer function for upgradeable contract */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * Sets the metadata for the Global
     *
     * @param globalId         Id of the global type to set
     * @param globalMetadata   Metadata of the global to set
     */
    function setMetadata(
        uint256 globalId,
        GlobalMetadata calldata globalMetadata
    ) external onlyRole(MANAGER_ROLE) {
        // Globals can only be set once!
        if (
            _globalMetadata[globalId].dataType != GlobalDataType.NOT_INITIALIZED
        ) {
            revert MetadataAlreadyInitialized(globalId);
        }

        if (bytes(globalMetadata.name).length == 0) {
            revert MustSetGlobalName(globalId);
        }

        if (globalMetadata.dataType == GlobalDataType.NOT_INITIALIZED) {
            revert MustSetGlobalDataType(globalId);
        }

        _globalMetadata[globalId] = globalMetadata;

        emit GlobalMetadataSet(globalId);
    }

    /**
     * Sets the value for a global boolean, also checks to make sure global can be modified
     *
     * @param globalId       Id of the global to modify
     * @param value          New value for the given global
     */
    function setBool(uint256 globalId, bool value)
        external
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
    {
        _setBool(globalId, value);

        emit GlobalUpdated(globalId);
    }

    /**
     * Sets the value for a global string, also checks to make sure global can be modified
     *
     * @param globalId        Id of the global to modify
     * @param value          New value for the given global
     */
    function setString(uint256 globalId, string calldata value)
        external
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
    {
        _setString(globalId, value);

        emit GlobalUpdated(globalId);
    }

    /**
     * Sets the value for a global string array, also checks to make sure global can be modified
     *
     * @param globalId        Id of the global to modify
     * @param values          New value for the given global
     */
    function setStringArray(uint256 globalId, string[] calldata values)
        external
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
    {
        _setStringArray(globalId, values);

        emit GlobalUpdated(globalId);
    }

    /**
     * Sets several string globals
     *
     * @param globalIds      Ids of globals to set
     * @param values         Value of globals to set
     */
    function batchSetString(uint256[] memory globalIds, string[] memory values)
        external
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
    {
        if (globalIds.length == 0 || globalIds.length != values.length) {
            revert InvalidArrayLengths();
        }

        uint256 lastGlobalId = 0;

        for (uint32 idx; idx < globalIds.length; ++idx) {
            _setString(globalIds[idx], values[idx]);
            if (lastGlobalId != globalIds[idx]) {
                emit GlobalUpdated(globalIds[idx]);
                lastGlobalId = globalIds[idx];
            }
        }
    }

    /**
     * Sets the value for the uint256 global, also checks to make sure global can be modified
     *
     * @param globalId        Id of the global to modify
     * @param value          New value for the given global
     */
    function setUint256(uint256 globalId, uint256 value)
        external
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
    {
        _setUint256(globalId, value);

        emit GlobalUpdated(globalId);
    }

    /**
     * Sets the value for the int256 global, also checks to make sure global can be modified
     *
     * @param globalId        Id of the global to modify
     * @param value          New value for the given global
     */
    function setInt256(uint256 globalId, int256 value)
        external
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
    {
        _setInt256(globalId, value);

        emit GlobalUpdated(globalId);
    }

    /**
     * Sets the value for the uint256 array global, also checks to make sure global can be modified
     *
     * @param globalId        Id of the global to modify
     * @param values          New value for the given global
     */
    function setUint256Array(uint256 globalId, uint256[] memory values)
        external
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
    {
        _setUint256Array(globalId, values);

        emit GlobalUpdated(globalId);
    }

    /**
     * Sets the value for the int256 array global, also checks to make sure global can be modified
     *
     * @param globalId        Id of the global to modify
     * @param values          New value for the given global
     */
    function setInt256Array(uint256 globalId, int256[] memory values)
        external
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
    {
        _setInt256Array(globalId, values);

        emit GlobalUpdated(globalId);
    }

    /**
     * Sets several uint256 globals
     *
     * @param globalIds    Ids of globals to set
     * @param values         Value of global to set
     */
    function batchSetUint256(
        uint256[] memory globalIds,
        uint256[] memory values
    ) external override onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        if (globalIds.length == 0 || globalIds.length != values.length) {
            revert InvalidArrayLengths();
        }

        uint256 lastGlobalId = 0;

        for (uint32 idx; idx < globalIds.length; ++idx) {
            _setUint256(globalIds[idx], values[idx]);
            if (lastGlobalId != globalIds[idx]) {
                emit GlobalUpdated(globalIds[idx]);
                lastGlobalId = globalIds[idx];
            }
        }
    }

    /**
     * Sets several int256 globals
     *
     * @param globalIds    Ids of globals to set
     * @param values         Value of global to set
     */
    function batchSetInt256(uint256[] memory globalIds, int256[] memory values)
        external
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
    {
        if (globalIds.length == 0 || globalIds.length != values.length) {
            revert InvalidArrayLengths();
        }

        uint256 lastGlobalId = 0;

        for (uint32 idx; idx < globalIds.length; ++idx) {
            _setInt256(globalIds[idx], values[idx]);
            if (lastGlobalId != globalIds[idx]) {
                emit GlobalUpdated(globalIds[idx]);
                lastGlobalId = globalIds[idx];
            }
        }
    }

    /**
     * Returns data for a global variable containing a boolean
     *
     * @param globalId  Id of the global to retrieve
     *
     * @return Global value as a bool
     */
    function getBool(uint256 globalId) external view override returns (bool) {
        GlobalDataType dataType = _globalMetadata[globalId].dataType;
        if (dataType != GlobalDataType.BOOL) {
            revert DataTypeMismatch(globalId, GlobalDataType.BOOL, dataType);
        }

        return _globalValueBool[globalId];
    }

    /**
     * Returns data for a global variable containing an uint
     *
     * @param globalId Id of the global to retrieve
     *
     * @return Global value as a uint256
     */
    function getUint256(uint256 globalId)
        external
        view
        override
        returns (uint256)
    {
        GlobalDataType dataType = _globalMetadata[globalId].dataType;
        if (dataType != GlobalDataType.UINT256) {
            revert DataTypeMismatch(globalId, GlobalDataType.UINT256, dataType);
        }

        return _globalValueUint256[globalId];
    }

    /**
     * Returns data for a global variable containing
     * an array of unit256
     *
     * @param globalId Id of the global to retrieve
     *
     * @return Global value as a uint256[]
     */
    function getUint256Array(uint256 globalId)
        external
        view
        override
        returns (uint256[] memory)
    {
        GlobalDataType dataType = _globalMetadata[globalId].dataType;
        if (dataType != GlobalDataType.UINT256_ARRAY) {
            revert DataTypeMismatch(
                globalId,
                GlobalDataType.UINT256_ARRAY,
                dataType
            );
        }

        uint256[] memory result = _globalValueUint256Array[globalId];
        return result;
    }

    /**
     * Returns data for a global variable containing an int
     *
     * @param globalId Id of the global to retrieve
     *
     * @return Global value as a int256
     */
    function getInt256(uint256 globalId)
        external
        view
        override
        returns (int256)
    {
        GlobalDataType dataType = _globalMetadata[globalId].dataType;
        if (dataType != GlobalDataType.INT256) {
            revert DataTypeMismatch(globalId, GlobalDataType.INT256, dataType);
        }

        return _globalValueInt256[globalId];
    }

    /**
     * Returns data for a global variable containing
     * an array of int256
     *
     * @param globalId Id of the global to retrieve
     *
     * @return Global value as a int256[]
     */
    function getInt256Array(uint256 globalId)
        external
        view
        override
        returns (int256[] memory)
    {
        GlobalDataType dataType = _globalMetadata[globalId].dataType;
        if (dataType != GlobalDataType.INT256_ARRAY) {
            revert DataTypeMismatch(
                globalId,
                GlobalDataType.INT256_ARRAY,
                dataType
            );
        }

        int256[] memory result = _globalValueInt256Array[globalId];
        return result;
    }

    /**
     * Returns data for a global variable containing a string
     *
     * @param globalId  Id of the global to retrieve
     *
     * @return Global value as a string
     */
    function getString(uint256 globalId)
        external
        view
        override
        returns (string memory)
    {
        GlobalDataType dataType = _globalMetadata[globalId].dataType;
        if (dataType != GlobalDataType.STRING) {
            revert DataTypeMismatch(globalId, GlobalDataType.STRING, dataType);
        }

        return _globalValueString[globalId];
    }

    /**
     * Returns data for a global variable containing
     * an array of strings
     *
     * @param globalId  Id of the global to retrieve
     *
     * @return Global value as a string[]
     */
    function getStringArray(uint256 globalId)
        external
        view
        override
        returns (string[] memory)
    {
        GlobalDataType dataType = _globalMetadata[globalId].dataType;
        if (dataType != GlobalDataType.STRING_ARRAY) {
            revert DataTypeMismatch(
                globalId,
                GlobalDataType.STRING_ARRAY,
                dataType
            );
        }

        return _globalValueStringArray[globalId];
    }

    /**
     * @param globalId  Id of the global to get metadata for
     * @return Metadata for the given global
     */
    function getMetadata(uint256 globalId)
        external
        view
        override
        returns (GlobalMetadata memory)
    {
        return _globalMetadata[globalId];
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IGameGlobals).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    /** PRIVATE **/

    /** Sets an uint256 global value */
    function _setUint256(uint256 globalId, uint256 value) private {
        GlobalDataType dataType = _globalMetadata[globalId].dataType;
        if (dataType != GlobalDataType.UINT256) {
            revert DataTypeMismatch(globalId, GlobalDataType.UINT256, dataType);
        }

        _globalValueUint256[globalId] = value;
    }

    /** Sets an uint256 array global value */
    function _setUint256Array(uint256 globalId, uint256[] memory values)
        private
    {
        GlobalDataType dataType = _globalMetadata[globalId].dataType;
        if (dataType != GlobalDataType.UINT256_ARRAY) {
            revert DataTypeMismatch(
                globalId,
                GlobalDataType.UINT256_ARRAY,
                dataType
            );
        }

        _globalValueUint256Array[globalId] = values;
    }

    /** Sets an int256 global value */
    function _setInt256(uint256 globalId, int256 value) private {
        GlobalDataType dataType = _globalMetadata[globalId].dataType;
        if (dataType != GlobalDataType.INT256) {
            revert DataTypeMismatch(globalId, GlobalDataType.INT256, dataType);
        }

        _globalValueInt256[globalId] = value;
    }

    /** Sets an int256 array global value */
    function _setInt256Array(uint256 globalId, int256[] memory values) private {
        GlobalDataType dataType = _globalMetadata[globalId].dataType;
        if (dataType != GlobalDataType.INT256_ARRAY) {
            revert DataTypeMismatch(
                globalId,
                GlobalDataType.INT256_ARRAY,
                dataType
            );
        }

        _globalValueInt256Array[globalId] = values;
    }

    /** Sets a boolean global value */
    function _setBool(uint256 globalId, bool value) private {
        GlobalDataType dataType = _globalMetadata[globalId].dataType;
        if (dataType != GlobalDataType.BOOL) {
            revert DataTypeMismatch(globalId, GlobalDataType.BOOL, dataType);
        }

        _globalValueBool[globalId] = value;
    }

    /** Sets a string global value */
    function _setString(uint256 globalId, string memory value) private {
        GlobalDataType dataType = _globalMetadata[globalId].dataType;
        if (dataType != GlobalDataType.STRING) {
            revert DataTypeMismatch(globalId, GlobalDataType.STRING, dataType);
        }

        _globalValueString[globalId] = value;
    }

    /** Sets a string array global value */
    function _setStringArray(uint256 globalId, string[] memory values) private {
        GlobalDataType dataType = _globalMetadata[globalId].dataType;
        if (dataType != GlobalDataType.STRING_ARRAY) {
            revert DataTypeMismatch(
                globalId,
                GlobalDataType.STRING_ARRAY,
                dataType
            );
        }

        _globalValueStringArray[globalId] = values;
    }

    /** Reverts if the global has not been initialized yet */
    function _requireGlobalMetadata(uint256 globalId)
        private
        view
        returns (GlobalMetadata memory)
    {
        GlobalMetadata memory globalMetadata = _globalMetadata[globalId];
        if (globalMetadata.dataType == GlobalDataType.NOT_INITIALIZED) {
            revert MetadataNotInitialized(globalId);
        }

        return globalMetadata;
    }
}
