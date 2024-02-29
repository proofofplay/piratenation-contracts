// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

uint256 constant ID = uint256(keccak256("game.piratenation.shipskinsystem"));

/// @title Interface for ship skin system
interface IShipSkinSystem {
    /**
     * Sets, unsets, or replaces a ship skin
     */
    function handleSkin(uint256 targetEntity, uint256 itemEntity) external;
}
