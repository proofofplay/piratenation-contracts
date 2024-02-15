// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

/**
 * @param objectEntity   Entity of the scene object to place
 * @param instanceEntity Entity of the instance; include to modify a placed object
 * @param x              X coordinate
 * @param y              Y coordinate
 * @param z              Z coordinate
 * @param rotation       Rotation of the item
 */
struct SceneObjectParams {
    uint256 objectEntity;
    uint256 instanceEntity;
    int64 x;
    int64 y;
    int64 z;
    int64 rotation;
}

interface ISceneSystem {
    /**
     * Add a game item to the scene, burning the game item in inventory in the process.
     *
     * @param sceneEntity       Entity of the scene
     * @param addedObjectParams Array of parameters for each game item to add
     */
    function addOrUpdateSceneObjects(
        uint256 sceneEntity,
        SceneObjectParams[] calldata addedObjectParams
    ) external;

    /**
     * Delete the game items in the scene and return them to the player's inventory.
     *
     * @param sceneEntity             Entity of the scene
     * @param removedInstanceEntities Array of entities of the item instances to remove
     */
    function removeSceneObjects(
        uint256 sceneEntity,
        uint256[] calldata removedInstanceEntities
    ) external;

    /**
     * Single contract call combining removeGameItems and addOrUpdateGameItems.
     *
     * @param sceneEntity             Entity of the scene
     * @param removedInstanceEntities Array of entities of the item instances to remove
     * @param addedObjectParams       Array of parameters for each game item to add
     */
    function updateScene(
        uint256 sceneEntity,
        uint256[] calldata removedInstanceEntities,
        SceneObjectParams[] calldata addedObjectParams
    ) external;
}
