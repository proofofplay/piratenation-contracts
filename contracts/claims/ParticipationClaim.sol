// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import {IClaimable} from "../claims/IClaimable.sol";
import {MANAGER_ROLE, GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";

import "../GameRegistryConsumerUpgradeable.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.claims.participation")
);

/**
 * @title Participation Claim
 *
 * Just a very simple claim in which people are either eligible or are not.
 */
contract ParticipationClaim is IClaimable, GameRegistryConsumerUpgradeable {
    /** MEMBERS **/

    // Whether an account is allowed to claim.
    // claim ➞ eligibleAccountAddress ➞ isEligible
    mapping(uint256 => mapping(address => bool)) accountIsEligible;

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

    function canClaim(address account, uint256 claim)
        external
        view
        returns (bool)
    {
        return accountIsEligible[claim][account];
    }

    function performAdditionalClaimActions(address account, uint256 claim)
        external
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
    {}

    function addWinner(address account, uint256 claim)
        public
        onlyRole(MANAGER_ROLE)
    {
        accountIsEligible[claim][account] = true;
    }

    function removeWinner(address account, uint256 claim)
        public
        onlyRole(MANAGER_ROLE)
    {
        accountIsEligible[claim][account] = false;
    }

    function batchAddWinners(address[] calldata accounts, uint256 claim)
        public
        onlyRole(MANAGER_ROLE)
    {
        for (uint256 idx; idx < accounts.length; ++idx) {
            addWinner(accounts[idx], claim);
        }
    }

    function batchRemoveWinners(address[] calldata accounts, uint256 claim)
        public
        onlyRole(MANAGER_ROLE)
    {
        for (uint256 idx; idx < accounts.length; ++idx) {
            removeWinner(accounts[idx], claim);
        }
    }
}
