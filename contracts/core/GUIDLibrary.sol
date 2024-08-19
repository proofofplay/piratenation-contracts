// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";

import {IGameRegistry} from "./IGameRegistry.sol";
import {CounterComponent, Layout as CounterLayout, ID as COUNTER_COMPONENT_ID} from "../generated/components/CounterComponent.sol";
import {GuidCounterComponent, ID as GUID_COUNTER_COMPONENT_ID} from "../generated/components/GuidCounterComponent.sol";

string constant GUID_PREFIX = "game.piratenation.guid.";

/// @notice Error thrown when the counter is too large to fit in 144 bits
error CounterOverflow(uint256 counter);

/// @notice Error thrown when the chain ID is too large to fit in 32 bits
error ChainIdOverflow(uint256 chainId);

/**
 * Common helper functions for dealing with GUIDS
 */
library GUIDLibrary {
    /**
     * @dev DEPRECATED: Increments the counter for a given key and returns a new GUID
     * @dev WARNING: Does NOT generated cross-chain safe guids
     * @param gameRegistry Address of the Counter component
     * @param key A prefix to namespace the GUID and prevent collisions
     */
    function guidV1(
        IGameRegistry gameRegistry,
        string memory key
    ) internal returns (uint256) {
        string memory prefix = string.concat(GUID_PREFIX, key);
        uint256 entity = uint256(keccak256(abi.encodePacked(prefix)));
        CounterComponent counterComponent = CounterComponent(
            gameRegistry.getComponent(COUNTER_COMPONENT_ID)
        );

        // Increment counter
        uint256 ct = counterComponent.getValue(entity) + 1;
        counterComponent.setValue(entity, ct);

        // Return new guid
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        string.concat(prefix, ".", Strings.toString(ct))
                    )
                )
            );
    }


    /**
     * Increments the counter for a given prefix and returns a new multi-chain safe GUID
     * @param gameRegistry Address of the GuidCounter component
     * @param prefix A prefix to namespace the GUID and prevent collisions
     */
    function guid(
        IGameRegistry gameRegistry,
        uint80 prefix
    ) internal returns (uint256) {
        GuidCounterComponent counter = GuidCounterComponent(
            gameRegistry.getComponent(GUID_COUNTER_COMPONENT_ID)
        );

        // Increment guid counter
        uint256 count = counter.getValue(prefix) + 1;
        counter.setValue(prefix, count);
        return packGuid(prefix, count);
    }

    /**
     * Packs prefix and counter into a multi-chain safe GUID
     * @param prefix A prefix to namespace the GUID and prevent collisions
     * @param counter A counter to increment the GUID
     */
    function packGuid(
        uint80 prefix,
        uint256 counter
    ) internal view returns (uint256) {
        if (block.chainid > type(uint32).max) {
            revert ChainIdOverflow(block.chainid);
        }
        if (counter > type(uint144).max) {
            revert CounterOverflow(counter);
        }

        // Pack into a uint256:
        // - Chain ID in the highest 32 bits
        // - Prefix in the next 80 bits (10 characters)
        // - Counter in the lowest 144 bits
        return (block.chainid << 224) | (prefix << 144) | counter;
    }
}
