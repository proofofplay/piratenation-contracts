// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {ICooldownSystem, ID} from "./ICooldownSystem.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";

contract CooldownSystem is GameRegistryConsumerUpgradeable, ICooldownSystem {
    /** MEMBERS **/

    /// @notice map entity to a mapping of Cooldown Id to timeStamp
    mapping(uint256 => mapping(uint256 => uint32))
        private _entityToCooldownIdToTimestamp;

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * @dev Map an entity to a system cooldown Id to a timeStamp
     * @param entity can be address, nft, round, ability, etc
     * @param cooldownId keccak to system using cooldown
     * @param cooldownTime cooldown time limit to set for entity, example 12 hours
     * @return true if entity still in cooldown
     */
    function updateAndCheckCooldown(
        uint256 entity,
        uint256 cooldownId,
        uint32 cooldownTime
    ) external override onlyRole(GAME_LOGIC_CONTRACT_ROLE) returns (bool) {
        // Current time is past cooldown time, safe to proceed, update cooldown timestamp
        if (
            block.timestamp >=
            _entityToCooldownIdToTimestamp[entity][cooldownId]
        ) {
            _entityToCooldownIdToTimestamp[entity][cooldownId] =
                uint32(block.timestamp) +
                cooldownTime;
            return false;
        }
        return true;
    }

    /**
     * @dev Function to check if entity is in cooldown
     * @param entity can be address, nft, round, ability, etc
     * @param cooldownId keccak to system using cooldown
     * @return true if block.timestamp is before entities cooldown timestamp, meaning entity is still in cooldown
     */
    function isInCooldown(
        uint256 entity,
        uint256 cooldownId
    ) external view override returns (bool) {
        return
            block.timestamp <
            _entityToCooldownIdToTimestamp[entity][cooldownId];
    }

    /**
     * @dev Function return entity cooldown timestamp
     * @param entity can be address, nft, round, ability, etc
     * @param cooldownId keccak to system using cooldown
     * @return uint32 entity cooldown timestamp
     */
    function getCooldown(
        uint256 entity,
        uint256 cooldownId
    ) external view override returns (uint32) {
        return _entityToCooldownIdToTimestamp[entity][cooldownId];
    }

    /**
     * @dev Function for cleaning up an entity cooldown timestamp
     * @param entity can be address, nft, round, ability, etc
     * @param cooldownId keccak to system using cooldown
     */
    function deleteCooldown(
        uint256 entity,
        uint256 cooldownId
    ) external override onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        delete _entityToCooldownIdToTimestamp[entity][cooldownId];
    }

    /**
     * @dev Function to reduce desired cooldown by cooldownTime
     * @param entity can be address, nft, round, ability, etc
     * @param cooldownId keccak to system using cooldown
     * @param cooldownTime time to reduce cooldown by
     */
    function reduceCooldown(
        uint256 entity,
        uint256 cooldownId,
        uint32 cooldownTime
    ) external override onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _entityToCooldownIdToTimestamp[entity][cooldownId] -= cooldownTime;
    }
}
