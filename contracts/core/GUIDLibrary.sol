// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";

import {IGameRegistry} from "./IGameRegistry.sol";
import {CounterComponent, Layout as CounterLayout, ID as COUNTER_COMPONENT_ID} from "../generated/components/CounterComponent.sol";

string constant GUID_PREFIX = "game.piratenation.guid.";

/**
 * Common helper functions for dealing with GUIDS
 */
library GUIDLibrary {
    /**
     * @dev Increments the counter for a given key and returns a new GUID
     * @param gameRegistry Address of the Counter component
     * @param key A prefix to namespace the GUID and prevent collisions
     */
    function guid(
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
}
