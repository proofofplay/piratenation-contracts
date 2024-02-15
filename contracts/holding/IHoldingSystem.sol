// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

uint256 constant ID = uint256(keccak256("game.piratenation.holdingsystem"));

/**
 * @title HoldingSystem
 *
 * Grants the user rewards based on how long they've held a given NFT
 */
interface IHoldingSystem {
    /**
     * Number of claimed milestones for a token
     * @param tokenContract  Contract of the token that is being held
     * @param tokenId        Id of the token that is being held
     * @return uint256       Number of milestones claimed for that token
     */
    function milestonesClaimed(address tokenContract, uint256 tokenId)
        external
        view
        returns (uint256);
}
