// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface ILootCallbackV2 is IERC165 {
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

    /**
     * Calls the loot callback function with randomness
     *
     * @param account       Address to grant loot to
     * @param lootId        Loot id to use
     * @param amount        Amount to grant
     * @param randomWord    Random word for this callback
     *
     * @return Updated random word if it was changed
     */
    function grantLootWithRandomWord(
        address account,
        uint256 lootId,
        uint256 amount,
        uint256 randomWord
    ) external returns (uint256);

    /** @return Whether or not this callback needs randomness */
    function needsVRF() external view returns (bool);
}
