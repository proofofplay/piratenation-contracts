// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import {EntityLibrary} from "../core/EntityLibrary.sol";

import {IComponent} from "../core/components/IComponent.sol";

/**
 * Common helper functions for mixins
 */
library MixinLibrary {
    /**
     * @dev Get the bytes value for a given entity and mixin
     * @param entity Entity to get the value for
     * @param mixins Mixins to get the value for
     * @param component Component to get the value from
     */
    function getBytesValue(
        uint256 entity,
        uint256[] memory mixins,
        IComponent component
    ) internal view returns (bytes memory) {
        if (component.has(entity)) {
            return component.getBytes(entity);
        }
        for (uint256 idx = 0; idx < mixins.length; idx++) {
            if (component.has(mixins[idx])) {
                return component.getBytes(mixins[idx]);
            }
        }
        return abi.encode("");
    }
}
