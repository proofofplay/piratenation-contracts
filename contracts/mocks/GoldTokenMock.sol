// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "../tokens/goldtoken/GoldToken.sol";

/** @title GoldToken Mock for testing restricted functions */
contract GoldTokenMock is GoldToken {
    function mintForTests(address account, uint256 amount) public {
        _mint(account, amount);
    }
}
