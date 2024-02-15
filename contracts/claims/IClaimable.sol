// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

/**
 * @title Claiming System
 */
interface IClaimable {
    /**
     * * Check if a player is eligible to receive a reward.
     *
     * @param account       Address of the account to mint to
     * @param claim         The claim id within the contract, matches
     *                      the ClaimDefinition key
     *
     */
    function canClaim(address account, uint256 claim)
        external
        view
        returns (bool);

    // TODO: This becomes an optional function...maybe "performAdditionalClaimActions"?
    /**
     * Claim a reward for a player.
     *
     * @param account       Address of the account to mint to
     * @param claim         The claim id within the contract, matches
     *                      the ClaimDefinition key
     *
     */
    function performAdditionalClaimActions(address account, uint256 claim)
        external;
}
