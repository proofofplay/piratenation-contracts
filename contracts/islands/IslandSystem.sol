// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {SceneObjectParams} from "../scene/ISceneSystem.sol";
import {SceneObjectParentComponent, ID as SCENE_OBJECT_PARENT_COMPONENT_ID} from "../generated/components/SceneObjectParentComponent.sol";
import {SceneSystem} from "../scene/SceneSystem.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.islandsystem"));

/**
 * @title Contract for islands
 */
contract IslandSystem is SceneSystem {
    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /** INTERNAL **/

    /**
     * @inheritdoc SceneSystem
     */
    function _canAddOrUpdateSceneObject(
        uint256 sceneEntity,
        SceneObjectParams calldata objectParams
    ) internal view override returns (bool) {
        // If the object has already been placed, then check if it can be modified
        if (objectParams.instanceEntity != 0) {
            // Check if object instance belongs to the island
            if (
                SceneObjectParentComponent(
                    _gameRegistry.getComponent(SCENE_OBJECT_PARENT_COMPONENT_ID)
                ).getValue(objectParams.instanceEntity).parentEntity !=
                sceneEntity
            ) {
                return false;
            }
        } else {
            // TODO: Check other object constraints (e.g. maxPlacementCount, etc)
        }

        return true;
    }

    /**
     * @inheritdoc SceneSystem
     */
    function _canRemoveSceneObject(
        uint256 sceneEntity,
        uint256 instanceEntity
    ) internal view override returns (bool) {
        // Check if object instance belongs to the island
        return
            SceneObjectParentComponent(
                _gameRegistry.getComponent(SCENE_OBJECT_PARENT_COMPONENT_ID)
            ).getValue(instanceEntity).parentEntity == sceneEntity;
    }
}
