// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {ArrayLibrary} from "../libraries/ArrayLibrary.sol";

contract ArrayLibraryMock {
    function sortUint256Array(
        uint256[] memory data
    ) external pure returns (uint256[] memory) {
        return ArrayLibrary.sortUint256Array(data);
    }

    function sortUint256ArrayDesc(
        uint256[] memory data2
    ) external pure returns (uint256[] memory) {
        return ArrayLibrary.sortUint256ArrayDesc(data2);
    }
}
