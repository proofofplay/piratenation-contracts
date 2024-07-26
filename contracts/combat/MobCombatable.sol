// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {EntityLibrary} from "../core/EntityLibrary.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";

import {ICombatable} from "./ICombatable.sol";

import {IsEnemyComponent, ID as IsEnemyComponentId, Layout as IsEnemyComponentLayout} from "..//generated/components/IsEnemyComponent.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.mobcombatable"));

contract MobCombatable is GameRegistryConsumerUpgradeable, ICombatable {
    /** ERRORS **/

    /// @notice Invalid mob contract
    error InvalidEntity();

    /// @notice Error when function is not implemented
    error NotImplemented();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * @inheritdoc ICombatable
     */
    function canBeAttacked(
        uint256 entityId,
        uint256[] calldata
    ) external view override returns (bool) {
        IsEnemyComponent isEnemyComponent = IsEnemyComponent(
            _gameRegistry.getComponent(IsEnemyComponentId)
        );

        if (!isEnemyComponent.getValue(entityId)) {
            revert InvalidEntity();
        }

        return true;
    }

    /**
     * @inheritdoc ICombatable
     */
    function canAttack(
        address,
        uint256,
        uint256[] calldata
    ) external pure override returns (bool) {
        return false;
    }
}
