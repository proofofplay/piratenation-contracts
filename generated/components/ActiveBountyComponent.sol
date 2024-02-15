// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseComponent, IComponent} from "../../core/components/BaseComponent.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.activebountycomponent"));

/**
 * @title ActiveBountyComponent
 * @dev This component is used to mark the active bounty for a player.
 */
contract ActiveBountyComponent is BaseComponent {
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
        keys = new string[](6);
        values = new TypesLibrary.SchemaValue[](6);
    
        // The status of the bounty (uint256 rep of the enum).
        keys[0] = "status";
        values[0] = TypesLibrary.SchemaValue.UINT32;
    
        // User wallet address
        keys[1] = "account";
        values[1] = TypesLibrary.SchemaValue.ADDRESS;
    
        // Active bounty start time
        keys[2] = "start_time";
        values[2] = TypesLibrary.SchemaValue.UINT32;
    
        // Bounty id
        keys[3] = "bounty_id";
        values[3] = TypesLibrary.SchemaValue.UINT256;
    
        // Group id
        keys[4] = "group_id";
        values[4] = TypesLibrary.SchemaValue.UINT256;
    
        // Entity inputs used for this bounty
        keys[5] = "entity_inputs";
        values[5] = TypesLibrary.SchemaValue.UINT256_ARRAY;
    
    }

    /**
     * Sets the typed value for this component
     *
     * @param entity Entity to get value for 
     * @param status uint32 The status of the bounty (uint256 rep of the enum).    
     * @param account address User wallet address    
     * @param startTime uint32 Active bounty start time    
     * @param bountyId uint256 Bounty id    
     * @param groupId uint256 Group id    
     * @param entityInputs uint256[] Entity inputs used for this bounty    
     */
    function setValue(
        uint256 entity,
        uint32 status,
        address account,
        uint32 startTime,
        uint256 bountyId,
        uint256 groupId,
        uint256[] memory entityInputs
    ) external virtual {
        setBytes(entity, abi.encode(status, account, startTime, bountyId, groupId, entityInputs));
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
            uint32 status,
            address account,
            uint32 startTime,
            uint256 bountyId,
            uint256 groupId,
            uint256[] memory entityInputs
        )
    {
        if (has(entity)) {
            (status, account, startTime, bountyId, groupId, entityInputs) = abi.decode(
                getBytes(entity),
                (uint32, address, uint32, uint256, uint256, uint256[])
            );
        }
    }
}
