// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseComponent, IComponent} from "../../core/components/BaseComponent.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.energycomponent"));

/**
 * @title EnergyComponent
 * @dev Holds information about an NFT&#39;s level of energy and regeneration rate
 */
contract EnergyComponent is BaseComponent {
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
    
        // Energy amount at time of last spend
        keys[0] = "last_energy_amount";
        values[0] = TypesLibrary.SchemaValue.UINT256;
    
        // Timestamp the energy was last spent
        keys[1] = "last_spend_timestamp";
        values[1] = TypesLibrary.SchemaValue.UINT256;
    
        // Energy allowed to be earned
        keys[2] = "last_energy_earnable";
        values[2] = TypesLibrary.SchemaValue.UINT256;
    
        // Last time energy was earned
        keys[3] = "last_earn_timestamp";
        values[3] = TypesLibrary.SchemaValue.UINT256;
    
    }

    /**
     * Sets the typed value for this component
     *
     * @param entity Entity to get value for 
     * @param lastEnergyAmount uint256 Energy amount at time of last spend    
     * @param lastSpendTimestamp uint256 Timestamp the energy was last spent    
     * @param lastEnergyEarnable uint256 Energy allowed to be earned    
     * @param lastEarnTimestamp uint256 Last time energy was earned    
     */
    function setValue(
        uint256 entity,
        uint256 lastEnergyAmount,
        uint256 lastSpendTimestamp,
        uint256 lastEnergyEarnable,
        uint256 lastEarnTimestamp
    ) external virtual {
        setBytes(entity, abi.encode(lastEnergyAmount, lastSpendTimestamp, lastEnergyEarnable, lastEarnTimestamp));
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
            uint256 lastEnergyAmount,
            uint256 lastSpendTimestamp,
            uint256 lastEnergyEarnable,
            uint256 lastEarnTimestamp
        )
    {
        if (has(entity)) {
            (lastEnergyAmount, lastSpendTimestamp, lastEnergyEarnable, lastEarnTimestamp) = abi.decode(
                getBytes(entity),
                (uint256, uint256, uint256, uint256)
            );
        }
    }
}
