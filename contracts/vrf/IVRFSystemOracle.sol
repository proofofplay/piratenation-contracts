// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.26;

interface IVRFSystemOracle {
    function deliverRandomNumber(
        uint256 requestId,
        uint256 roundNumber,
        uint256 randomNumber
    ) external;
}
