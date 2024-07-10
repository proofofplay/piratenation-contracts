// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IVRFConsumer {
    function recievedRandomNumber(uint256 _id, uint256 _value) external;
}
