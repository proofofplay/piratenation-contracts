// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import {TimeRangeComponent, Layout as TimeRangeComponentStruct} from "../generated/components/TimeRangeComponent.sol";

/**
 * Common helper functions for dealing with TimeRange component
 */
library TimeRangeLibrary {
    /**
     * @dev Checks if the current block timestamp is within the time range of the given entity
     * @param timeRangeComponent Address of the TimeRange component
     * @param entity Entity ID to check
     * @return True if the current block timestamp is within the time range of the given entity
     */
    function checkWithinTimeRange(
        address timeRangeComponent,
        uint256 entity
    ) internal view returns (bool) {
        TimeRangeComponentStruct memory value = TimeRangeComponent(
            timeRangeComponent
        ).getLayoutValue(entity);
        if (
            block.timestamp >= value.startTime &&
            block.timestamp < value.endTime
        ) {
            return true;
        } else {
            return false;
        }
    }

    function checkWithinOptionalTimeRange(
        address timeRangeComponent,
        uint256 entity
    ) internal view returns (bool) {
        TimeRangeComponentStruct memory value = TimeRangeComponent(
            timeRangeComponent
        ).getLayoutValue(entity);
        if (
            (value.startTime != 0 && block.timestamp < value.startTime) ||
            (value.endTime != 0 && block.timestamp >= value.endTime)
        ) {
            return false;
        } else {
            return true;
        }
    }
}
