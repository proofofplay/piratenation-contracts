// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "../loot/LootSystem.sol";

/** @title Loot System Mock for testing */
contract LootSystemMock is LootSystem {
    bytes4 public constant LOOTSYSTEM_INTERFACEID =
        type(ILootSystem).interfaceId;
}
