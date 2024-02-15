// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

/** @title Common utility functions for the game **/
library UtilLibrary {
    /** @return Convert an int256 to a string */
    function int2str(int256 value) internal pure returns (string memory) {
        // Adapted from OpenZepplin Strings.sol
        if (value == 0) {
            return "0";
        }
        bool negative = value < 0;
        uint256 unsignedValue = uint256(negative ? -value : value);
        uint256 temp = unsignedValue;
        uint256 digits = negative ? 1 : 0;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (unsignedValue != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(unsignedValue % 10)));
            unsignedValue /= 10;
        }

        if (negative) {
            buffer[0] = "-";
        }

        return string(buffer);
    }
}
