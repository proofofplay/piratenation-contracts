// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import {IGameRegistry} from "../core/IGameRegistry.sol";

import {RequestStatusComponent, ID as REQUEST_STATUS_COMPONENT_ID, Layout as RequestStatusComponentLayout} from "../generated/components/RequestStatusComponent.sol";

// Pub/Sub Role - manages cross-chain communication
bytes32 constant PUB_SUB_ORACLE_ROLE = keccak256("PUB_SUB_ORACLE_ROLE");

// Entity describing the chain itself
uint256 constant CHAIN_ENTITY = uint256(
    keccak256("game.piratenation.chainentity.v1")
);

enum RequestStatus {
    UNDEFINED,
    COMPLETED,
    PENDING
}

library RequestLibrary {
    function publishCompletedComponentValueSet(
        IGameRegistry gameRegistry,
        uint256 componentId,
        uint256 entity,
        bytes memory data
    ) internal {
        uint256 requestId = gameRegistry.publishComponentValueSet(
            componentId,
            entity,
            data
        );
        createRequestStatus(
            gameRegistry,
            requestId,
            block.timestamp,
            RequestStatus.COMPLETED
        );
    }

    function batchPublishCompletedComponentValueSet(
        IGameRegistry gameRegistry,
        uint256 componentId,
        uint256[] memory entities,
        bytes[] memory data
    ) internal {
        uint256 requestId = gameRegistry.batchPublishComponentValueSet(
            componentId,
            entities,
            data
        );
        createRequestStatus(
            gameRegistry,
            requestId,
            block.timestamp,
            RequestStatus.COMPLETED
        );
    }

    function createRequestStatus(
        IGameRegistry gameRegistry,
        uint256 requestId,
        uint256 createdTime,
        RequestStatus status
    ) internal {
        RequestStatusComponent(
            gameRegistry.getComponent(REQUEST_STATUS_COMPONENT_ID)
        ).setLayoutValue(
                requestId,
                RequestStatusComponentLayout({
                    createdTime: createdTime,
                    completedTime: block.timestamp,
                    status: uint8(status)
                })
            );
    }
}
