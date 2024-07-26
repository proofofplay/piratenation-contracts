// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {ICombatable} from "./ICombatable.sol";

abstract contract Combatable is GameRegistryConsumerUpgradeable, ICombatable {}
