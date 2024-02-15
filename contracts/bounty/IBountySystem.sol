// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

uint256 constant ID = uint256(keccak256("game.piratenation.bountysystem"));

/// @title Interface for the BountySystem that lets players go on bounties (time-based quests)
interface IBountySystem {
    /**
     * Whether or not a given bounty is available to the given player
     *
     * @param account Account to check if quest is available for
     * @param bountyComponentId Id of the bounty to see is available
     *
     * @return Whether or not the bounty is available to the given account
     */
    function isBountyAvailable(
        address account,
        uint256 bountyComponentId
    ) external view returns (bool);

    function activeBountyIdsForAccount(
        address account
    ) external view returns (uint256[] memory);

    function setBountyStatus(uint256 bountyGroupId, bool enabled) external;

    function hasPendingBounty(
        address account,
        uint256 bountyGroupId
    ) external view returns (bool);
}
