// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

/**
 * @title PirateStake
 * @dev Interface for the PirateStake contract.
 */
contract PirateStake {
    /**
     * @notice UserStakeInfo struct to store user's staking information
     * @param erc20balance The amount of ERC20 tokens staked by the user
     * @param erc20initial The initial amount of ERC20 tokens staked by the user
     * @param accumulatedPoints The total points earned by the user over time
     * @param lastUpdatedTime The timestamp of the last update
     * @param multiplier The multiplier applied to the user's points
     */
    struct UserStakeInfo {
        uint256 erc20balance;
        uint256 erc20initial;
        uint256 accumulatedPoints;
        uint64 lastUpdatedTime;
        uint16 multiplier;
    }

    mapping(address => UserStakeInfo) public users;

    mapping(uint256 seasonId => mapping(address userWallet => UserStakeInfo stakeInfo))
        public seasonIdToUserToStakeInfo;

    function calculateAndFixPoints(
        address[] calldata usersToFixArray
    ) external {}

    /**
     * @notice Returns the base points earned by a user
     * @param user The address of the user
     * @return The base points earned by the user
     */
    function getBasePoints(
        uint256 season,
        address user
    ) public view returns (uint256) {}
}
