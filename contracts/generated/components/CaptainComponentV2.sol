// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TypesLibrary} from "../../core/TypesLibrary.sol";
import {BaseComponent, IComponent} from "../../core/components/BaseComponent.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.captaincomponentv2"));

/**
 * @title CaptainComponentV2
 * @dev Holds information about which pirate is captain for an account
 */
contract CaptainComponentV2 is BaseComponent {
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
    
        // Entity of the Pirate NFT
        keys[0] = "nft_entity";
        values[0] = TypesLibrary.SchemaValue.UINT256;
    
        // Time of last captain set
        keys[1] = "last_set_captain_time";
        values[1] = TypesLibrary.SchemaValue.UINT256;
    
    }

    /**
     * Sets the typed value for this component
     *
     * @param entity Entity to get value for 
     * @param nftEntity uint256 Entity of the Pirate NFT    
     * @param lastSetCaptainTime uint256 Time of last captain set    
     */
    function setValue(
        uint256 entity,
        uint256 nftEntity,
        uint256 lastSetCaptainTime
    ) external virtual {
        setBytes(entity, abi.encode(nftEntity, lastSetCaptainTime));
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
            uint256 nftEntity,
            uint256 lastSetCaptainTime
        )
    {
        if (has(entity)) {
            (nftEntity, lastSetCaptainTime) = abi.decode(
                getBytes(entity),
                (uint256, uint256)
            );
        }
    }
}
