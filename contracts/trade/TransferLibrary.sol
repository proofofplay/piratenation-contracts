// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {CreatedTimestampComponent} from "../generated/components/CreatedTimestampComponent.sol";
import {LootEntityArrayComponent, Layout as LootEntityArrayLayout} from "../generated/components/LootEntityArrayComponent.sol";
import {TransferStatusComponent, Layout as TransferStatusComponentLayout} from "../generated/components/TransferStatusComponent.sol";

enum TransferStatus {
    UNDEFINED,
    COMPLETED,
    REFUNDED
}

/**
 * Common helper functions for handling transfers
 */
library TransferLibrary {
    function generateTransferReceipt(
        address transferStatusComponent,
        address createdTimestampComponent,
        address lootEntityArrayComponent,
        address to,
        address from,
        uint256 entity,
        LootEntityArrayLayout memory lootEntityArray
    ) internal {
        TransferStatusComponent(transferStatusComponent).setLayoutValue(
            entity,
            TransferStatusComponentLayout({
                to: to,
                from: from,
                status: uint8(TransferStatus.COMPLETED)
            })
        );
        CreatedTimestampComponent(createdTimestampComponent).setValue(
            entity,
            block.timestamp
        );
        LootEntityArrayComponent(lootEntityArrayComponent).setLayoutValue(
            entity,
            lootEntityArray
        );
    }
}
