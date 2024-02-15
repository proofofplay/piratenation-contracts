// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import {IERC20BeforeTokenTransferHandler} from "@proofofplay/erc721-extensions/src/IERC20BeforeTokenTransferHandler.sol";

import {GameRegistryConsumerUpgradeable} from "../../GameRegistryConsumerUpgradeable.sol";
import {EntityLibrary} from "../../core/EntityLibrary.sol";
import {TradeLicenseComponent, ID as TRADE_LICENSE_COMPONENT_ID} from "../../generated/components/TradeLicenseComponent.sol";
import {TradeLibrary} from "../../trade/TradeLibrary.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.goldtokenbeforetokentransferhandler")
);

contract GoldTokenBeforeTokenTransferHandler is
    GameRegistryConsumerUpgradeable,
    IERC20BeforeTokenTransferHandler
{
    /** ERRORS **/

    /// @notice Cannot transfer zero amount
    error ZeroAmount();

    /** SETUP **/

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /** EXTERNAL **/

    /**
     * Before transfer hook for GameItems. Performs any trait checks needed before transfer
     *
     * @param from              From address
     * @param to               To address
     * @param amount         Amount to transfer
     */
    function beforeTokenTransfer(
        address, // tokenContract,
        address, // operator
        address from,
        address to,
        uint256 amount
    ) external view {
        // Cannot transfer zero amount
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (from != address(0)) {
            // Can burn PGLD
            if (to != address(0)) {
                // Check if wallet has TradeLicense
                TradeLibrary.checkTradeLicense(
                    TradeLicenseComponent(
                        _gameRegistry.getComponent(TRADE_LICENSE_COMPONENT_ID)
                    ),
                    EntityLibrary.addressToEntity(from)
                );
            }
        }
    }
}
