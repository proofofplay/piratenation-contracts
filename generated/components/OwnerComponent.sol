// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseComponent, IComponent} from "../../core/components/BaseComponent.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.ownercomponent"));

/**
 * @title OwnerComponent
 * @dev Reference to an entity owner
 */
contract OwnerComponent is BaseComponent {
    /** SETUP **/

    /** Sets the GameRegistry contract address for this contract  */
    constructor(
        address gameRegistryAddress
    ) BaseComponent(gameRegistryAddress, ID) {
        // Do nothing
    }

    /**
     * @inheritdoc IComponent
     */
    function getSchema()
        public
        pure
        override
        returns (string[] memory keys, TypesLibrary.SchemaValue[] memory values)
    {
        keys = new string[](1);
        values = new TypesLibrary.SchemaValue[](1);
    
        // Entity ID of the owner
        keys[0] = "value";
        values[0] = TypesLibrary.SchemaValue.UINT256;
    
    }

    /**
     * Sets the typed value for this component
     *
     * @param entity Entity to get value for 
     * @param value uint256 Entity ID of the owner    
     */
    function setValue(
        uint256 entity,
        uint256 value
    ) external virtual {
        setBytes(entity, abi.encode(value));
    }

    /**
     * Returns the typed value for this component
     *
     * @param entity Entity to get value for
     */
    function getValue(
        uint256 entity
    )
        external
        view
        virtual
        returns (
            uint256 value
        )
    {
        if (has(entity)) {
            (value) = abi.decode(
                getBytes(entity),
                (uint256)
            );
        }
    }
}
