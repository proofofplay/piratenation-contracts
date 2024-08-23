// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";

import {EntityLibrary} from "../core/EntityLibrary.sol";
import {OwnerSystem} from "../core/OwnerSystem.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {ITokenTemplateSystem, ID as TOKEN_TEMPLATE_SYSTEM_ID} from "../tokens/ITokenTemplateSystem.sol";
import {MANAGER_ROLE} from "../Constants.sol";
import {AccountStarterIslandComponent, ID as ACCOUNT_STARTER_ISLAND_COMPONENT_ID} from "../generated/components/AccountStarterIslandComponent.sol";
import {GUIDLibrary} from "../core/GUIDLibrary.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.islandspawnsystem"));

/**
 * @title IslandSpawnSystem
 *
 * Generates the starter islands for each player.
 */
contract IslandSpawnSystem is OwnerSystem {
    using Counters for Counters.Counter;

    /** ERRORS **/

    /// @notice Error when caller has already spawned an island
    error IslandAlreadySpawned(uint256 sceneEntity);

    /** MEMBERS **/

    /// @notice Counter to track island token ID
    Counters.Counter public _islandTokenIdCounter;

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * Generates a starter island that can be fetched from GQL
     */
    function spawnStarterIsland()
        external
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        AccountStarterIslandComponent starterIsland = AccountStarterIslandComponent(
                _gameRegistry.getComponent(ACCOUNT_STARTER_ISLAND_COMPONENT_ID)
            );

        address account = _getPlayerAccount(_msgSender());
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        uint256 sceneEntity = starterIsland.getValue(accountEntity);

        // Check caller has not already spawned an island.
        if (sceneEntity != 0) {
            revert IslandAlreadySpawned(sceneEntity);
        }

        sceneEntity = GUIDLibrary.guid(_gameRegistry, uint80(ID));

        starterIsland.setValue(accountEntity, sceneEntity);

        // Set ownership of the island
        _setEntityOwner(sceneEntity, account);

        return sceneEntity;
    }
}
