// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import {IERC20BeforeTokenTransferHandler} from "@proofofplay/erc721-extensions/src/IERC20BeforeTokenTransferHandler.sol";

import {GameRegistryConsumerUpgradeable} from "../../GameRegistryConsumerUpgradeable.sol";
import {EntityLibrary} from "../../core/EntityLibrary.sol";
import {TradeLicenseComponent, ID as TRADE_LICENSE_COMPONENT_ID} from "../../generated/components/TradeLicenseComponent.sol";
import {BanComponent, ID as BAN_COMPONENT_ID} from "../../generated/components/BanComponent.sol";
import {Banned} from "../../ban/BanSystem.sol";
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
     */
    function beforeTokenTransfer(
        address, // tokenContract,
        address, // operator
        address from,
        address, // to,
        uint256 // amount
    ) external view {
        if (from != address(0)) {
            // Is not banned
            if (
                BanComponent(_gameRegistry.getComponent(BAN_COMPONENT_ID))
                    .getValue(EntityLibrary.addressToEntity(from)) == true
            ) {
                revert Banned();
            }
        }
    }
}
