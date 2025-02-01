// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

uint256 constant ID = uint256(
    keccak256("game.piratenation.subscriptionsystem")
);

uint256 constant VIP_SUBSCRIPTION_TYPE = uint256(
    keccak256("game.piratenation.subscription.type.vip")
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

    /**
     * @dev Get the expiration time of a subscription
     * @param subscriptionType Type of subscription to check
     * @param account Address of the account to check
     */
    function getSubscriptionExpirationTime(
        uint256 subscriptionType,
        address account
    ) external view returns (uint32);
}
