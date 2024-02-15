// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "../tokens/goldtoken/GoldToken.sol";

/** @title GoldToken Mock for testing restricted functions */
contract GoldTokenMock is GoldToken {
    constructor(address gameRegistryAddress) GoldToken(gameRegistryAddress) {
        // Do nothing
    }

    function mintForTests(address account, uint256 amount) public {
        _mint(account, amount);
    }
}
