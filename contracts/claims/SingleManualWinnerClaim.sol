// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../GameRegistryConsumerUpgradeable.sol";

import {IClaimable} from "./IClaimable.sol";
import {ILootSystem, ID as LOOT_SYSTEM_ID} from "../loot/ILootSystem.sol";
import {MANAGER_ROLE, GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.claims.singlemanualwinner")
);

/**
 * @title A claimable that must be manually set to a single individual.
 *
 * This is intended to be used as the "Kill Shot" Boss Battle claim, but
 * can be generalized to other situations where we want want to just manually
 * grant an award to a single person.
 */
contract SingleManualWinnerClaim is
    IClaimable,
    GameRegistryConsumerUpgradeable
{
    mapping(uint256 => address) public winner;

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
        if (account == winner[claim]) {
            return true;
        } else {
            return false;
        }
    }

    function performAdditionalClaimActions(address account, uint256 claim)
        external
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
    {}

    function getWinner(uint256 claim) external view returns (address) {
        return winner[claim];
    }

    function setWinner(address newWinner, uint256 claim)
        external
        onlyRole(MANAGER_ROLE)
    {
        winner[claim] = newWinner;
    }
}
