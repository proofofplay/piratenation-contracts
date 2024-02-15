// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {TradeLicenseComponent, Layout as TradeLicenseComponentStruct, ID as TRADE_LICENSE_COMPONENT_ID} from "../generated/components/TradeLicenseComponent.sol";

/**
 * Common helper functions for dealing with Trade Licenses and AccountXp
 */
library TradeLibrary {
    /// @notice Invalid inputs
    error InvalidInputs();

    /// @notice Missing trade license
    error MissingTradeLicense();

    /**
     * @dev Check if accountEntity has a trade license
     * @param tradeLicenseComponent ID of the TradeLicenseComponent
     * @param accountEntity Entity to check for trade license
     */
    function checkTradeLicense(
        TradeLicenseComponent tradeLicenseComponent,
        uint256 accountEntity
    ) internal view {
        if (accountEntity == 0) {
            revert InvalidInputs();
        }
        // Get account trade license
        bool accountHasTradeLicense = tradeLicenseComponent
            .getLayoutValue(accountEntity)
            .hasTradeLicense;
        // If player doesnt have a trade license then revert
        if (accountHasTradeLicense == false) {
            revert MissingTradeLicense();
        }
    }

    /**
     * @dev Check if accountEntity has a trade license
     * @param tradeLicenseComponent ID of the TradeLicenseComponent
     * @param accountEntity Entity to check for trade license
     * @return True if account has a trade license
     */
    function hasTradeLicense(
        TradeLicenseComponent tradeLicenseComponent,
        uint256 accountEntity
    ) internal view returns (bool) {
        if (accountEntity == 0) {
            return false;
        }
        // Get account trade license
        return tradeLicenseComponent.getValue(accountEntity);
    }
}
