// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import "../ship/ShipSystemV2.sol";

/** @title ShipSystemV2 Mock for testing */
contract ShipSystemV2Mock is ShipSystemV2 {
    function grantLootForTests(
        address account,
        uint256 lootId,
        uint256 amount
    ) external {
        _grantLoot(account, lootId, amount);
    }
}