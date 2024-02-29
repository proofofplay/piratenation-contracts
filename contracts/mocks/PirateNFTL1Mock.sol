// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {PirateNFTL1} from "../mainnet/PirateNFTL1.sol";

/** @title PirateNFTL1  Mock for testing */
contract PirateNFTL1Mock is PirateNFTL1 {
    constructor(uint256 maxSupply) PirateNFTL1(maxSupply) {}
}
