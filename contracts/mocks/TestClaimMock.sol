// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import {IClaimable} from "../claims/IClaimable.sol";
// import {IAchievementSystem, ID as ACHIEVEMENT_SYSTEM_ID} from "../achievements/IAchievementSystem.sol";
import {IGoldToken, ID as GOLD_TOKEN_SYSTEM_ID} from "../tokens/goldtoken/IGoldToken.sol";

import "../GameRegistryConsumerUpgradeable.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.testingclaim"));
uint256 constant goldRewardAmount = 10000000000;

/**
 * @title Testing Claim
 *
 * Just a very simple claim for use in testing.
 */
contract TestClaimMock is IClaimable, GameRegistryConsumerUpgradeable {
    /** MEMBERS **/

    // Whether an account is allowed to claim.
    mapping(address => bool) accountIsEligible;

    // Whether an account has already claimed.
    mapping(address => bool) accountHasClaimed;

    /** ERRORS **/

    /// @notice Player does not meet criteria for achievement
    error CriteriaNotMet();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    function canClaim(address account, uint256) external view returns (bool) {
        return accountIsEligible[account];
    }

    function performAdditionalClaimActions(
        address account,
        uint256 claim
    ) external {
        if (this.canClaim(account, claim) == false) {
            revert CriteriaNotMet();
        }

        accountHasClaimed[account] = true;

        IGoldToken goldToken = IGoldToken(_getSystem(GOLD_TOKEN_SYSTEM_ID));

        goldToken.mint(account, goldRewardAmount);
    }

    function hasClaimed(address account) external view returns (bool) {
        return accountHasClaimed[account];
    }

    function setClaimingEnabled(address account) external {
        accountIsEligible[account] = true;
    }

    function setClaimingDisabled(address account) external {
        accountIsEligible[account] = false;
    }

    function getClaimingState(address account) external view returns (bool) {
        return accountIsEligible[account];
    }
}
