// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../GameRegistryConsumerUpgradeable.sol";

import {IClaimable} from "./IClaimable.sol";
import {ILootSystem, ID as LOOT_SYSTEM_ID} from "../loot/ILootSystem.sol";
import {MANAGER_ROLE, GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.claims.rankedrewards")
);

/**
 * @title Ranked Rewards Claim
 *
 * This contract allows you to map a reward set to an ordered list of winners.
 * This was originally intended to be used for the Top Damage Dealers claim,
 * such that the person who has dealt the most damage to the world boss gets
 * the biggest rewards, second place got a slightly smaller set of rewards, etc.
 *
 */
contract RankedRewardsClaim is IClaimable, GameRegistryConsumerUpgradeable {
    // claim ➞ the highest placement currently eligible to receive awards
    mapping(uint256 => uint256) public highestPlacement;

    // claim ➞ placement (1st place, 2nd place, etc.) ➞ set of Loots to award
    mapping(uint256 => mapping(uint256 => ILootSystem.Loot[]))
        public rewardsForPlacement;

    // claim ➞ winner's account address ➞ how they placed in the contest (1st, 2nd, etc.)
    mapping(uint256 => mapping(address => uint256)) public placementForWinner;

    /** ERRORS **/

    /// @notice Player does not meet criteria for achievement
    error WrongNumberOfWinners(uint256 expected, uint256 sent);

    /// @notice Player has an invalid placement for the claim
    error InvalidPlacementForWinner(uint256 claim, address account);

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    function canClaim(
        address account,
        uint256 claim
    ) external view returns (bool) {
        if (placementForWinner[claim][account] == 0) {
            revert InvalidPlacementForWinner(claim, account);
        }

        if (placementForWinner[claim][account] <= highestPlacement[claim]) {
            return true;
        } else {
            return false;
        }
    }

    function performAdditionalClaimActions(
        address account,
        uint256 claim
    ) external onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        uint256 placement = placementForWinner[claim][account];
        ILootSystem.Loot[] memory loots = rewardsForPlacement[claim][
            placement - 1
        ];
        ILootSystem lootSystem = ILootSystem(_getSystem(LOOT_SYSTEM_ID));
        lootSystem.grantLoot(account, loots);
    }

    function getLoot(
        uint256 claim,
        uint256 placement
    ) external view returns (ILootSystem.Loot[] memory) {
        return rewardsForPlacement[claim][placement];
    }

    function getPlacement(
        address account,
        uint256 claim
    ) external view returns (uint256) {
        return placementForWinner[claim][account];
    }

    function setLoots(
        uint256 claim,
        ILootSystem.Loot[][] memory newLoots
    ) external onlyRole(MANAGER_ROLE) {
        highestPlacement[claim] = newLoots.length;
        for (uint256 i; i < newLoots.length; i++) {
            _copyLoots(claim, i, newLoots[i]);
        }
    }

    function _copyLoots(
        uint256 claim,
        uint256 placement,
        ILootSystem.Loot[] memory newLoots
    ) private {
        ILootSystem.Loot[] storage placementSlot = rewardsForPlacement[claim][
            placement
        ];
        for (uint256 i; i < newLoots.length; i++) {
            placementSlot.push();
            placementSlot[i] = newLoots[i];
        }
    }

    function setWinners(
        address[] calldata newOrderedWinners,
        uint256 claim
    ) external onlyRole(MANAGER_ROLE) {
        uint256 localHighestPlacement = highestPlacement[claim];
        if (newOrderedWinners.length != localHighestPlacement) {
            revert WrongNumberOfWinners(
                localHighestPlacement,
                newOrderedWinners.length
            );
        }

        for (uint256 idx; idx < localHighestPlacement; ++idx) {
            address winner = newOrderedWinners[idx];
            placementForWinner[claim][winner] = idx + 1;
        }
    }
}
