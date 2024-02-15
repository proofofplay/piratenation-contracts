// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

import {TraitDataType, TokenURITrait} from "../interfaces/ITraitsProvider.sol";
import "./UtilLibrary.sol";

/// @dev Threshold before a UINT is rendered as a string in tokenURI JSON
uint256 constant JSON_MAX_UINT_SIZE = 1_000_000_000;

/// @dev Threshold before a INT is rendered as a string in tokenURI JSON
int256 constant JSON_MAX_INT_SIZE = 1_000_000_000;

/// @dev Threshold before a INT is rendered as a string in tokenURI JSON
int256 constant JSON_MIN_INT_SIZE = -1_000_000_000;

library JSONRenderer {
    using Strings for uint256;

    /** ERRORS **/

    /// @notice When the trait uri generation is passed an invalid datatype
    error InvalidTraitDataType(TraitDataType dataType);

    /** EXTERNAL **/

    /**
     * Generate a tokenURI based on a set of global properties and traits
     *
     * @param traits       Traits to render into the JSON
     *
     * @return base64-encoded fully-formed tokenURI
     */
    function generateTokenURI(
        TokenURITrait[] memory traits
    ) internal pure returns (string memory) {
        // Generate JSON strings
        string memory propertiesJSON = _generatePropertiesJSON(traits);
        string memory attributesJSON = _generateAttributesJSON(traits);
        string memory comma = bytes(propertiesJSON).length > 0 ? "," : "";

        string memory metadata = string.concat(
            "{",
            propertiesJSON,
            comma,
            '"attributes":[',
            attributesJSON,
            "]}"
        );

        return
            string.concat(
                "data:application/json;base64,",
                Base64.encode(bytes(metadata))
            );
    }

    /** INTERNAL **/

    function _generatePropertiesJSON(
        TokenURITrait[] memory allTraits
    ) internal pure returns (string memory) {
        string memory propertiesJSON = "";
        bool isFirstElement = true;
        for (uint256 idx; idx < allTraits.length; ++idx) {
            TokenURITrait memory trait = allTraits[idx];
            if (trait.isTopLevelProperty == false) {
                continue;
            }

            // Skip hidden traits
            if (trait.hidden) {
                continue;
            }

            string memory value = _traitValueToString(trait);
            string memory comma = isFirstElement ? "" : ",";

            propertiesJSON = string.concat(
                propertiesJSON,
                comma,
                '"',
                trait.name,
                '":',
                value
            );
            isFirstElement = false;
        }

        return propertiesJSON;
    }

    /**
     * @param allTraits  All of the traits for a given token to use to generate a attributes JSON array
     * @return a JSON string for all of the attributes for the given token
     */
    function _generateAttributesJSON(
        TokenURITrait[] memory allTraits
    ) internal pure returns (string memory) {
        string memory finalString = "";

        bool isFirstElement = true;
        for (uint256 idx; idx < allTraits.length; ++idx) {
            TokenURITrait memory trait = allTraits[idx];

            // Skip if its not an attribute type
            if (trait.isTopLevelProperty == true) {
                continue;
            }

            // Skip hidden traits
            if (trait.hidden) {
                continue;
            }

            // Skip including attribute if the string value is empty
            if (
                trait.dataType == TraitDataType.STRING &&
                bytes(abi.decode(trait.value, (string))).length == 0
            ) {
                continue;
            }

            string memory json = _attributeJSON(trait);
            string memory comma = isFirstElement ? "" : ",";
            finalString = string.concat(finalString, comma, json);
            isFirstElement = false;
        }

        return finalString;
    }

    /** @return Token metadata attribute JSON string */
    function _attributeJSON(
        TokenURITrait memory trait
    ) internal pure returns (string memory) {
        string memory value = _traitValueToString(trait);
        return
            string.concat(
                '{"trait_type":"',
                trait.name,
                '","value":',
                value,
                "}"
            );
    }

    /** Converts a trait's numeric or string value into a printable JSON string value */
    function _traitValueToString(
        TokenURITrait memory trait
    ) internal pure returns (string memory) {
        TraitDataType dataType = trait.dataType;

        // NOTE: if numberic value is outside JSON MAX/MIN values, change it to a
        // string so that we may preserve precision when passing to BigNumber.
        if (dataType == TraitDataType.STRING) {
            string memory value = abi.decode(trait.value, (string));
            return string.concat('"', value, '"');
        } else if (dataType == TraitDataType.BOOL) {
            bool value = abi.decode(trait.value, (bool));
            return value ? '"true"' : '"false"';
        } else if (dataType == TraitDataType.UINT) {
            uint256 value = abi.decode(trait.value, (uint256));

            if (value > JSON_MAX_UINT_SIZE) {
                return string.concat('"', value.toString(), '"');
            } else {
                return value.toString();
            }
        } else if (dataType == TraitDataType.INT) {
            int256 value = abi.decode(trait.value, (int256));
            string memory strValue = UtilLibrary.int2str(value);

            if (value > JSON_MAX_INT_SIZE || value < JSON_MIN_INT_SIZE) {
                return string.concat('"', strValue, '"');
            } else {
                return strValue;
            }
        } else if (dataType == TraitDataType.UINT_ARRAY) {
            uint256[] memory value = abi.decode(trait.value, (uint256[]));
            string memory strValue;
            for (uint8 idx; idx < value.length; ++idx) {
                strValue = string.concat(
                    strValue,
                    idx == 0 ? "" : ",",
                    value[idx] > JSON_MAX_UINT_SIZE
                        ? string.concat('"', value[idx].toString(), '"')
                        : value[idx].toString()
                );
            }
            return string.concat("[", strValue, "]");
        } else if (dataType == TraitDataType.INT_ARRAY) {
            int256[] memory value = abi.decode(trait.value, (int256[]));
            string memory strValue;
            for (uint8 idx; idx < value.length; ++idx) {
                string memory strPart = UtilLibrary.int2str(value[idx]);
                strValue = string.concat(
                    strValue,
                    idx == 0 ? "" : ",",
                    value[idx] > JSON_MAX_INT_SIZE ||
                        value[idx] < JSON_MIN_INT_SIZE
                        ? string.concat('"', strPart, '"')
                        : strPart
                );
            }
            return string.concat("[", strValue, "]");
        }

        revert InvalidTraitDataType(trait.dataType);
    }
}
