// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {GAME_LOGIC_CONTRACT_ROLE, MANAGER_ROLE} from "../Constants.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {ID, ICountingSystem} from "./ICountingSystem.sol";

/// @notice Be sure to list your counting key in `packages/shared/src/countingIds.ts`.
contract CountingSystem is ICountingSystem, GameRegistryConsumerUpgradeable {
    /** MEMBERS */
    /// @notice This should be an entity ➞ keccak256 hash ➞ count (value).
    // The creation of that keccak256 is left as an exercise for the caller.
    mapping(uint256 => mapping(uint256 => uint256)) public counters;

    /** EVENTS */

    /// @notice Emitted when the count has been forcibly set.
    event CountSet(uint256 entity, uint256 key, uint256 newTotal);

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * Get the stored counter's value.
     *
     * @param entity    The entity in the mapping.
     * @param key       The key in the mapping.
     * @return value    The value in the mapping.
     */
    function getCount(
        uint256 entity,
        uint256 key
    ) external view returns (uint256) {
        return counters[entity][key];
    }

    /**
     * Set the stored counter's value.
     * (Mostly intended for debug purposes.)
     *
     * @param entity    The entity in the mapping.
     * @param key       The key in the mapping.
     * @param value     The value in the mapping.
     */
    function setCount(
        uint256 entity,
        uint256 key,
        uint256 value
    ) external onlyRole(GAME_LOGIC_CONTRACT_ROLE) whenNotPaused {
        counters[entity][key] = value;
        emit CountSet(entity, key, value);
    }

    /**
     * Increments the stored counter by some amount.
     *
     * @param entity    The entity in the mapping.
     * @param key       The key in the mapping.
     * @param amount    The amount to increment by.
     */
    function incrementCount(
        uint256 entity,
        uint256 key,
        uint256 amount
    ) external onlyRole(GAME_LOGIC_CONTRACT_ROLE) whenNotPaused {
        counters[entity][key] += amount;
        emit CountSet(entity, key, counters[entity][key]);
    }
}
