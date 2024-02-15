// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../libraries/GameRegistryLibrary.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.gachasystem"));

/// @title Interface for the GachaSystem that holds ERC tokens and disperses at a random index
interface IGachaSystem {
    /**
     * @dev Returns the current count of tokens in the GachaSystem for a given GachaComponent
     */
    function supply(uint256 gachaComponentId) external view returns (uint256);

    /**
     * @dev Triggers the GachaSystem to dispense a random token to caller
     */
    function dispense(uint256 gachaComponentId) external;
}
