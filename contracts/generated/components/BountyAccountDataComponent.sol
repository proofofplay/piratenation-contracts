// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseComponent, IComponent} from "../../core/components/BaseComponent.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.bountyaccountdatacomponent"));

/**
 * @title BountyAccountDataComponent
 * @dev Bounty Account Data
 */
contract BountyAccountDataComponent is BaseComponent {
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
        keys = new string[](2);
        values = new TypesLibrary.SchemaValue[](2);
    
        // User wallet address
        keys[0] = "account";
        values[0] = TypesLibrary.SchemaValue.ADDRESS;
    
        // Array of user active bounty IDs
        keys[1] = "active_bounty_ids";
        values[1] = TypesLibrary.SchemaValue.UINT256_ARRAY;
    
    }

    /**
     * Sets the typed value for this component
     *
     * @param entity Entity to get value for 
     * @param account address User wallet address    
     * @param activeBountyIds uint256[] Array of user active bounty IDs    
     */
    function setValue(
        uint256 entity,
        address account,
        uint256[] memory activeBountyIds
    ) external virtual {
        setBytes(entity, abi.encode(account, activeBountyIds));
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
            address account,
            uint256[] memory activeBountyIds
        )
    {
        if (has(entity)) {
            (account, activeBountyIds) = abi.decode(
                getBytes(entity),
                (address, uint256[])
            );
        }
    }
}
