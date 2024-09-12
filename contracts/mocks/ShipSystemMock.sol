// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "../ship/ShipSystemV2.sol";

/** @title ShipSystem Mock for testing */
contract ShipSystemMock is ShipSystemV2 {
    function grantLootForTests(
        address account,
        uint256 lootId,
        uint256 amount
    ) external {
        _mintAndInitializeLoot(account, lootId, amount);
    }
}
