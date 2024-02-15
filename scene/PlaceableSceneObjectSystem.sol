// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {IS_PLACEABLE_TRAIT_ID, GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {Layout as TransformP3R1, TransformP3R1Component, ID as TRANSFORM_P3R1_COMPONENT_ID} from "../generated/components/TransformP3R1Component.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {ITraitsProvider} from "../interfaces/ITraitsProvider.sol";
import {SceneObjectGameItem, SceneObjectGameItemComponent, ID as SCENE_OBJECT_GAME_ITEM_COMPONENT_ID} from "../generated/components/SceneObjectGameItemComponent.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.placeablesceneobjectsystem")
);

/**
 * @title Contract for PlaceableSceneObjects
 */
contract PlaceableSceneObjectSystem is GameRegistryConsumerUpgradeable {
    /** ERRORS **/

    /// @notice Invalid item cannot be added to the scene
    error ItemNotPlaceable(address tokenContract, uint256 tokenId);

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * Creates a new placeableSceneObject from a gameItem.
     */
    function create(
        uint256 itemEntity,
        TransformP3R1 calldata transform
    )
        external
        virtual
        whenNotPaused
        nonReentrant
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (uint256 instanceEntity)
    {
        return _create(itemEntity, transform);
    }

    /**
     * Returns the data for a placeableSceneObject.
     *
     * @dev For debug purposes only. Do not use in production.
     *
     * @param instanceEntity The entity to get data for.
     * @return data The data for the placeableSceneObject.
     */
    function readPlacement(
        uint256 instanceEntity
    ) external view returns (TransformP3R1 memory data) {
        // Get Item Instance Specific Data
        return
            TransformP3R1Component(
                _gameRegistry.getComponent(TRANSFORM_P3R1_COMPONENT_ID)
            ).getValue(instanceEntity);
    }

    /**
     * Update the values of a placeableSceneObject.
     */
    function update(
        uint256 instanceEntity,
        TransformP3R1 calldata transform
    ) external whenNotPaused nonReentrant onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        TransformP3R1Component(
            _gameRegistry.getComponent(TRANSFORM_P3R1_COMPONENT_ID)
        ).setValue(instanceEntity, transform);
    }

    /**
     * Delete the placeableSceneObject.
     */
    function remove(
        uint256 instanceEntity
    ) external whenNotPaused nonReentrant onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        SceneObjectGameItemComponent(
            _gameRegistry.getComponent(SCENE_OBJECT_GAME_ITEM_COMPONENT_ID)
        ).remove(instanceEntity);
        TransformP3R1Component(
            _gameRegistry.getComponent(TRANSFORM_P3R1_COMPONENT_ID)
        ).remove(instanceEntity);
    }

    /** INTERNAL **/

    function _create(
        uint256 itemEntity,
        TransformP3R1 calldata transform
    ) internal returns (uint256 instanceEntity) {
        (address tokenContract, uint256 tokenId) = EntityLibrary.entityToToken(
            itemEntity
        );

        if (!_isPlaceable(tokenContract, tokenId)) {
            revert ItemNotPlaceable(tokenContract, tokenId);
        }

        instanceEntity = _gameRegistry.generateGUID();

        SceneObjectGameItemComponent(
            _gameRegistry.getComponent(SCENE_OBJECT_GAME_ITEM_COMPONENT_ID)
        ).setValue(
                instanceEntity,
                SceneObjectGameItem({itemEntity: itemEntity})
            );
        TransformP3R1Component(
            _gameRegistry.getComponent(TRANSFORM_P3R1_COMPONENT_ID)
        ).setValue(instanceEntity, transform);
    }

    /**
     * @dev Returns true if the scene object is placeable, false otherwise.
     * @param tokenContract The contract address of the object.
     * @param tokenId The token id of the object.
     * @return isPlaceable Whether the object is placeable.
     */
    function _isPlaceable(
        address tokenContract,
        uint256 tokenId
    ) internal view returns (bool isPlaceable) {
        ITraitsProvider traitsProvider = _traitsProvider();
        isPlaceable = traitsProvider.hasTrait(
            tokenContract,
            tokenId,
            IS_PLACEABLE_TRAIT_ID
        )
            ? traitsProvider.getTraitBool(
                tokenContract,
                tokenId,
                IS_PLACEABLE_TRAIT_ID
            )
            : false;
    }
}
