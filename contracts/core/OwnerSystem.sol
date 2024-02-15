// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "../GameRegistryConsumerUpgradeable.sol";

import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {OwnerComponent, ID as OWNER_COMPONENT_ID} from "../generated/components/OwnerComponent.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";

abstract contract OwnerSystem is GameRegistryConsumerUpgradeable {
    /** ERRORS **/

    /// @notice Invalid owner for operation
    error InvalidOwnerForEntity(uint256 entity);

    /// @notice Invalid owner for operation
    error InvalidEntity(uint256 entity);

    /**
     * @dev Modifier to make a function callable only if caller owns the passed in entity.
     */
    modifier onlyEntityOwner(uint256 entity) {
        _onlyEntityOwner(entity);
        _;
    }

    /** INTERNAL **/

    function _onlyEntityOwner(uint256 entity) private view {
        address owner = EntityLibrary.entityToAddress(OwnerComponent(
            _gameRegistry.getComponent(OWNER_COMPONENT_ID)
        ).getValue(entity));

        if (owner != _getPlayerAccount(_msgSender())) {
            revert InvalidOwnerForEntity(entity);
        }
    }

    /**
     * @dev Function to set caller as the entity owner.
     */
    function _setEntityOwner(uint256 entity, address account) internal {
        OwnerComponent ownerComponent = OwnerComponent(
            _gameRegistry.getComponent(OWNER_COMPONENT_ID)
        );

        // Only set the owner if it is not already set.
        if (EntityLibrary.entityToAddress(ownerComponent.getValue(entity)) != address(0)) {
            revert InvalidEntity(entity);
        }

        ownerComponent.setValue(entity, EntityLibrary.addressToEntity(account));
    }
}
