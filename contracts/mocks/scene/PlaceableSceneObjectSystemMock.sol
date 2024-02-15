// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {Layout as TransformP3R1} from "../../generated/components/TransformP3R1Component.sol";
import {EntityLibrary} from "../../core/EntityLibrary.sol";

import {PlaceableSceneObjectSystem} from "../../scene/PlaceableSceneObjectSystem.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";

contract PlaceableSceneObjectSystemMock is PlaceableSceneObjectSystem {
    error InvalidBossEnity(uint256 entityId);

    // itemEntity ➞ array of instance entities belonging to that item
    mapping(uint256 => uint256[]) public itemInstances;

    function create(
        uint256 itemEntity,
        TransformP3R1 calldata transform
    )
        external
        override
        whenNotPaused
        nonReentrant
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (uint256 instanceEntity)
    {
        instanceEntity = _create(itemEntity, transform);

        // Record instance entities
        itemInstances[itemEntity].push(instanceEntity);

        return instanceEntity;
    }

    function getItemInstances(
        uint256 itemEntity
    ) external view returns (uint256[] memory) {
        return itemInstances[itemEntity];
    }
}
