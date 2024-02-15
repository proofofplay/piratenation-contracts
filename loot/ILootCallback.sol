// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

interface ILootCallback {
    /**
     * Calls the loot callback function
     * @param account   Address to grant loot to
     * @param lootId    Loot id to use
     * @param amount    Amount to grant
     */
    function grantLoot(
        address account,
        uint256 lootId,
        uint256 amount
    ) external;
}
