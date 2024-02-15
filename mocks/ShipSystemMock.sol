// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "../ship/ShipSystem.sol";

/** @title ShipSystem Mock for testing */
contract ShipSystemMock is ShipSystem {
    function grantLootForTests(
        address account,
        uint256 lootId,
        uint256 amount
    ) external {
        _grantLoot(account, lootId, amount);
    }
}
