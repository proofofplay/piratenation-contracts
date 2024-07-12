// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {MANAGER_ROLE} from "../Constants.sol";
import {BanComponent, ID as BAN_COMPONENT_ID, Layout as BanComponentLayout} from "../generated/components/BanComponent.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.bansystem"));

error Banned();
error UserAlreadyBanned(address account);

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

    /**
     * Ban any number of accounts
     *
     * @param accounts List of accounts to ban
     */
    function banAccounts(
        address[] calldata accounts
    ) public nonReentrant whenNotPaused onlyRole(MANAGER_ROLE) {
        uint256[] memory accountEntities = new uint256[](accounts.length);
        BanComponentLayout[] memory banValues = new BanComponentLayout[](
            accounts.length
        );
        for (uint256 i = 0; i < accounts.length; i++) {
            accountEntities[i] = EntityLibrary.addressToEntity(accounts[i]);
            if (_isBanned(accountEntities[i])) {
                revert UserAlreadyBanned(accounts[i]);
            }
            banValues[i] = BanComponentLayout(true);
        }
        BanComponent(_gameRegistry.getComponent(BAN_COMPONENT_ID))
            .batchSetValue(accountEntities, banValues);

        //todo: We need to burn all their items on TradeableGameItems and TradeableShipNFT to prevent them from trading?
        //note: we can add this later, for now let's get quick to market to at least block trading.
    }

    /**
     * Unban any number of accounts
     *
     * @param accounts List of accounts to unban
     */
    function unbanAccounts(
        address[] calldata accounts
    ) public nonReentrant whenNotPaused onlyRole(MANAGER_ROLE) {
        uint256[] memory accountEntities = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            accountEntities[i] = EntityLibrary.addressToEntity(accounts[i]);
        }
        BanComponentLayout[] memory banValues = new BanComponentLayout[](
            accountEntities.length
        );
        // No need to initialize banValues[i] as Layout(false) because a bool value in Solidity is false by default
        BanComponent(_gameRegistry.getComponent(BAN_COMPONENT_ID))
            .batchSetValue(accountEntities, banValues);
    }

    /**
     * Check if an account address is banned
     *
     * @param account Address to check
     * @return Boolean indicating if account is banned
     */
    function isBanned(address account) public view returns (bool) {
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        return _isBanned(accountEntity);
    }

    /** INTERNAL */

    function _isBanned(uint256 accountEntity) internal view returns (bool) {
        return
            BanComponent(_gameRegistry.getComponent(BAN_COMPONENT_ID)).getValue(
                accountEntity
            );
    }
}
