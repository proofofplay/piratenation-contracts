// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {MANAGER_ROLE} from "../Constants.sol";
import {BanComponent, ID as BAN_COMPONENT_ID} from "../generated/components/BanComponent.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.bansystem"));

error Banned();
error UserAlreadyBanned();

/**
 * @title TradeLicenseSystem
 */
contract BanSystem is GameRegistryConsumerUpgradeable {
    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /** EXTERNAL */

    function banAccount(
        address account
    ) public nonReentrant whenNotPaused onlyRole(MANAGER_ROLE) {
        uint256 accountEntity = EntityLibrary.addressToEntity(account);

        //todo: check if user has been banned or not.
        bool isBanned = BanComponent(
            _gameRegistry.getComponent(BAN_COMPONENT_ID)
        ).getValue(accountEntity);

        if (isBanned) {
            revert UserAlreadyBanned();
        }

        // Ban user
        BanComponent(_gameRegistry.getComponent(BAN_COMPONENT_ID)).setValue(
            accountEntity,
            true
        );

        //todo: We need to burn all their items on TradeableGameItems and TradeableShipNFT to prevent them from trading?
        //note: we can add this later, for now let's get quick to market to at least block trading.
    }

    function unbanAccount(
        address account
    ) public nonReentrant whenNotPaused onlyRole(MANAGER_ROLE) {
        uint256 accountEntity = EntityLibrary.addressToEntity(account);

        // Ban user
        BanComponent(_gameRegistry.getComponent(BAN_COMPONENT_ID)).setValue(
            accountEntity,
            false
        );
    }
}
