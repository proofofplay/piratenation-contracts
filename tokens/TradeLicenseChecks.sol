// SPDX-License-Identifier: MIT

/**
 * Adds simple trade license checking helpers to a contract
 */

pragma solidity ^0.8.13;

import {TradeLibrary} from "../trade/TradeLibrary.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {TradeLicenseComponent, ID as TRADE_LICENSE_COMPONENT_ID} from "../generated/components/TradeLicenseComponent.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";

abstract contract TradeLicenseChecks is GameRegistryConsumerUpgradeable {
    /**
     * @dev Verifies the from address has a trade license, reverts if false.
     * @param from address to check
     */
    function _checkTradeLicense(address from) internal view {
        TradeLibrary.checkTradeLicense(
            TradeLicenseComponent(
                _gameRegistry.getComponent(TRADE_LICENSE_COMPONENT_ID)
            ),
            EntityLibrary.addressToEntity(from)
        );
    }

    function _hasTradeLicense(address who) internal view returns (bool) {
        return
            TradeLibrary.hasTradeLicense(
                TradeLicenseComponent(
                    _gameRegistry.getComponent(TRADE_LICENSE_COMPONENT_ID)
                ),
                EntityLibrary.addressToEntity(who)
            );
    }
}
