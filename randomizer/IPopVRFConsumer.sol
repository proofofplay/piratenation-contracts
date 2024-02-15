// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

interface IPopVRFConsumer {
    function recievedRandomNumber(uint256 id, uint256 value) external;
}
