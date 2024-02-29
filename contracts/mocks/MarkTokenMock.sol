// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "../tokens/goldtoken/MarkToken.sol";

/** @title MarkToken Mock for testing restricted functions */
contract MarkTokenMock is MarkToken {
    function mintForTests(address account, uint256 amount) public {
        _mint(account, amount);
    }
}
