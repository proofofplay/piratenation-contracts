// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import {IComponent} from "../core/components/IComponent.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {CounterComponent, ID as COUNTER_COMPONENT_ID} from "../generated/components/CounterComponent.sol";
import {RequestIdComponent, ID as REQUEST_ID_COMPONENT_ID} from "../generated/components/RequestIdComponent.sol";
import {RequestStatusComponent, ID as REQUEST_STATUS_COMPONENT_ID, Layout as RequestStatusComponentLayout} from "../generated/components/RequestStatusComponent.sol";
import {PUB_SUB_ORACLE_ROLE, RequestLibrary, RequestStatus} from "./RequestLibrary.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.subscribersystem.v1")
);

/// @notice Error thrown when new registrations are disabled
error RequestAlreadyCompleted(uint256 requestId);

/// @notice Error thrown when a request is executed out of order
error RequestIsStale(uint256 requestId);

/// @notice Error thrown when no valid values are available to set
error NoValidValuesToSet();

contract SubscriberSystem is GameRegistryConsumerUpgradeable {
    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * Delivers a ComponentValueSet request
     */
    function deliverComponentValueSet(
        uint256 requestId,
        uint256 componentId,
        uint256 entity,
        uint256 requestTime,
        bytes calldata data
    ) external whenNotPaused nonReentrant onlyRole(PUB_SUB_ORACLE_ROLE) {
        // Check if request was already delivered before
        if (_isDelivered(requestId)) {
            revert RequestAlreadyCompleted(requestId);
        }

        // Check if request has been executed out of order
        if (
            _isStaleRequest(
                _getLatestRequestKey(entity, componentId),
                requestId,
                requestTime
            ) == true
        ) {
            revert RequestIsStale(requestId);
        }

        // Set the component value
        IComponent(_gameRegistry.getComponent(componentId)).setBytes(
            entity,
            data
        );

        // Mark request as completed
        RequestLibrary.createRequestStatus(
            _gameRegistry,
            requestId,
            requestTime,
            RequestStatus.COMPLETED
        );
    }

    /**
     * Delivers a BatchComponentValueSet request
     */
    function deliverBatchComponentValueSet(
        uint256 requestId,
        uint256 componentId,
        uint256[] calldata entities,
        uint256 requestTime,
        bytes[] calldata data
    ) external whenNotPaused nonReentrant onlyRole(PUB_SUB_ORACLE_ROLE) {
        // Check if request was already delivered before
        if (_isDelivered(requestId)) {
            revert RequestAlreadyCompleted(requestId);
        }

        // Filter out any requests that are stale
        uint256[] memory filteredEntities = new uint256[](entities.length);
        bytes[] memory filteredData = new bytes[](data.length);
        uint256 counter = 0;
        for (uint256 i = 0; i < entities.length; i++) {
            if (
                _isStaleRequest(
                    _getLatestRequestKey(entities[i], componentId),
                    requestId,
                    requestTime
                ) == true
            ) {
                continue;
            }

            filteredEntities[counter] = entities[i];
            filteredData[counter] = data[i];
            counter++;
        }

        if (counter == 0) {
            revert NoValidValuesToSet();
        }

        // Trim arrays
        assembly {
            mstore(filteredEntities, counter)
            mstore(filteredData, counter)
        }

        // Batch set the component values
        IComponent(_gameRegistry.getComponent(componentId)).batchSetBytes(
            filteredEntities,
            filteredData
        );

        // Mark request as completed
        RequestLibrary.createRequestStatus(
            _gameRegistry,
            requestId,
            requestTime,
            RequestStatus.COMPLETED
        );
    }

    /**
     * Delivers a BatchSetComponentValue request (Not to be confused with BatchComponentValueSet)
     */
    function deliverBatchSetComponentValue(
        uint256 requestId,
        uint256[] calldata componentIds,
        uint256[] calldata entities,
        uint256 requestTime,
        bytes[] calldata datas
    ) external whenNotPaused nonReentrant onlyRole(PUB_SUB_ORACLE_ROLE) {
        // Check if request was already delivered before
        if (_isDelivered(requestId)) {
            revert RequestAlreadyCompleted(requestId);
        }

        _gameRegistry.batchSetComponentValue(entities, componentIds, datas);

        // Mark request as completed
        RequestLibrary.createRequestStatus(
            _gameRegistry,
            requestId,
            requestTime,
            RequestStatus.COMPLETED
        );
    }

    /**
     * Checks if a request has been delivered
     *
     * @param requestId Request entity to check
     */
    function isDelivered(uint256 requestId) external view returns (bool) {
        return _isDelivered(requestId);
    }

    /** INTERNAL **/

    /**
     * Resolves an entity for a componentId and entity combination
     */
    function _getLatestRequestKey(
        uint256 entity,
        uint256 componentId
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(entity, componentId)));
    }

    /**
     * Checks if a request has been delivered
     */
    function _isDelivered(uint256 requestId) internal view returns (bool) {
        return
            RequestStatusComponent(
                _gameRegistry.getComponent(REQUEST_STATUS_COMPONENT_ID)
            ).getLayoutValue(requestId).status ==
            uint8(RequestStatus.COMPLETED);
    }

    /**
     * Returns true for stale requests; otherwise track this request as latest for entity + component
     */
    function _isStaleRequest(
        uint256 latestRequestKey,
        uint256 requestId,
        uint256 requestTime
    ) internal returns (bool) {
        if (latestRequestKey == 0) {
            return false;
        }

        RequestIdComponent requestIdComponent = RequestIdComponent(
            _gameRegistry.getComponent(REQUEST_ID_COMPONENT_ID)
        );

        // Compare the createdTime for latest request with the current requestTime
        uint256 latestRequestId = requestIdComponent.getValue(latestRequestKey);
        uint256 latestRequestTime = RequestStatusComponent(
            _gameRegistry.getComponent(REQUEST_STATUS_COMPONENT_ID)
        ).getLayoutValue(latestRequestId).createdTime;

        if (latestRequestTime > requestTime) {
            return true;
        }

        // Track the latest request for the entity
        requestIdComponent.setValue(latestRequestKey, requestId);
        return false;
    }
}
