// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

interface IPopVRF {
    function request() external returns (uint256);
}
