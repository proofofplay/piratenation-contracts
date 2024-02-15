// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

uint256 constant ID = uint256(keccak256("game.piratenation.achievementsystem"));

/**
 * @title Achievement Systems
 */
interface IAchievementSystem {
    /**
     * Grants an achievement to a player
     *
     * @param account       Address of the account to mint to
     * @param templateId    NFT template tokenId of achievement to mint
     * @param traitIds      Metadata trait ids to set on the achievement
     * @param traitValues   Metadata trait values to set on the achievement
     *
     */
    function grantAchievement(
        address account,
        uint256 templateId,
        uint256[] calldata traitIds,
        string[] calldata traitValues
    ) external;

    /**
     * Adjusts the counter of achievement token ids to a given value
     *
     * @param newValue      New value to set the counter to
     */
    function adjustCounter(uint256 newValue) external;
}
