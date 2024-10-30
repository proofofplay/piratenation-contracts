// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

uint256 constant ID = uint256(
    keccak256("game.piratenation.subscriptionsystem")
);

/// @title Interface for handling subscriptions
interface ISubscriptionSystem {
    /**
     * @dev Check if an account has an active subscription
     * @param subscriptionType Type of subscription to check
     * @param account Address of the account to check
     */
    function checkHasActiveSubscription(
        uint256 subscriptionType,
        address account
    ) external view returns (bool);
}
