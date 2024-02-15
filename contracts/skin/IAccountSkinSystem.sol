// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

uint256 constant ID = uint256(keccak256("game.piratenation.accountskinsystem"));

/// @title Interface for vanity system
interface IAccountSkinSystem {
    /**
     * Handles setting and unsetting a vanity skin
     */
    function handleVanity(uint256 targetEntity, uint256 itemEntity) external;
}
