// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IGameCurrency} from "../IGameCurrency.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.goldtoken"));

interface IGoldToken is IGameCurrency {}
