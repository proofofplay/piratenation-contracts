// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

/**
 * @title Array utility functions
 */
library ArrayLibrary {
    /**
     * @dev Returns array of uint256's sorted in place and in ascending order
     */
    function sortUint256Array(
        uint256[] memory data
    ) internal pure returns (uint256[] memory) {
        _quickSortUint256Array(data, 0, int256(data.length - 1), true);
        return data;
    }

    /**
     * @dev Returns array of uint256's sorted in place and in descending order
     */
    function sortUint256ArrayDesc(
        uint256[] memory data
    ) internal pure returns (uint256[] memory) {
        _quickSortUint256Array(data, 0, int256(data.length - 1), false);
        return data;
    }

    /** INTERNAL **/

    function _quickSortUint256Array(
        uint256[] memory arr,
        int256 left,
        int256 right,
        bool asc
    ) internal pure {
        int256 i = left;
        int256 j = right;
        if (i == j) {
            return;
        }
        uint256 pivot = arr[uint256(left + (right - left) / 2)];
        while (i <= j) {
            while (asc ? arr[uint256(i)] < pivot : arr[uint256(i)] > pivot) {
                i++;
            }
            while (asc ? pivot < arr[uint256(j)] : pivot > arr[uint256(j)]) {
                j--;
            }
            if (i <= j) {
                (arr[uint256(i)], arr[uint256(j)]) = (
                    arr[uint256(j)],
                    arr[uint256(i)]
                );
                i++;
                j--;
            }
        }
        if (left < j) {
            _quickSortUint256Array(arr, left, j, asc);
        }
        if (i < right) {
            _quickSortUint256Array(arr, i, right, asc);
        }
    }
}
