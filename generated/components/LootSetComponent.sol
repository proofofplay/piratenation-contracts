// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseComponent, IComponent} from "../../core/components/BaseComponent.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.lootsetcomponent"));

/**
 * @title LootSetComponent
 * @dev Loot Set Component
 */
contract LootSetComponent is BaseComponent {
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
        keys = new string[](4);
        values = new TypesLibrary.SchemaValue[](4);
    
        // Type of fulfillment (ERC721, ERC1155, ERC20, LOOT_TABLE)
        keys[0] = "loot_type";
        values[0] = TypesLibrary.SchemaValue.UINT32_ARRAY;
    
        // Contract to grant tokens from
        keys[1] = "token_contract";
        values[1] = TypesLibrary.SchemaValue.ADDRESS_ARRAY;
    
        // Id of the token to grant (ERC1155/LOOT TABLE/CALLBACK types only)
        keys[2] = "loot_id";
        values[2] = TypesLibrary.SchemaValue.UINT256_ARRAY;
    
        // Amount of token to grant (XP, ERC20, ERC1155)
        keys[3] = "amount";
        values[3] = TypesLibrary.SchemaValue.UINT256_ARRAY;
    
    }

    /**
     * Sets the typed value for this component
     *
     * @param entity Entity to get value for 
     * @param lootType uint32[] Type of fulfillment (ERC721, ERC1155, ERC20, LOOT_TABLE)    
     * @param tokenContract address[] Contract to grant tokens from    
     * @param lootId uint256[] Id of the token to grant (ERC1155/LOOT TABLE/CALLBACK types only)    
     * @param amount uint256[] Amount of token to grant (XP, ERC20, ERC1155)    
     */
    function setValue(
        uint256 entity,
        uint32[] memory lootType,
        address[] memory tokenContract,
        uint256[] memory lootId,
        uint256[] memory amount
    ) external virtual {
        setBytes(entity, abi.encode(lootType, tokenContract, lootId, amount));
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
            uint32[] memory lootType,
            address[] memory tokenContract,
            uint256[] memory lootId,
            uint256[] memory amount
        )
    {
        if (has(entity)) {
            (lootType, tokenContract, lootId, amount) = abi.decode(
                getBytes(entity),
                (uint32[], address[], uint256[], uint256[])
            );
        }
    }
}
