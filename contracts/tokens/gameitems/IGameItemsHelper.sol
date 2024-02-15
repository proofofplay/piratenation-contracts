// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

uint256 constant ID = uint256(keccak256("game.piratenation.gameitemshelper"));

/// @title Interface for GameItemsHelper
interface IGameItemsHelper {
    /**
     * Batch mint game items
     */
    function batchMint(
        address[] calldata addresses,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external;

    /**
     * Batch mint single game item to multiple addresses
     */
    function batchAddressMint( 
        address[] calldata addresses,
        uint256 id,
        uint256 amount
    ) external;
}
