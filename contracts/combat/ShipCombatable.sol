// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {ShipEquipment, ID as SHIP_EQUIPMENT_ID} from "../equipment/ShipEquipment.sol";
import {ID as PIRATE_NFT_ID} from "../tokens/PirateNFTL2.sol";
import {ID as STARTER_PIRATE_NFT_ID} from "../tokens/starterpiratenft/StarterPirateNFT.sol";
import {IShipNFT} from "../tokens/shipnft/IShipNFT.sol";
import {ID as SHIP_NFT_ID} from "../tokens/shipnft/ShipNFT.sol";
import {IsPirateComponent, ID as IS_PIRATE_COMPONENT_ID} from "../generated/components/IsPirateComponent.sol";
import {Combatable} from "./Combatable.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.shipcombatable"));

contract ShipCombatable is Combatable {
    /** ERRORS **/

    /// @notice Invalid Ship contract
    error InvalidShipEntity();

    /// @notice Invalid Pirate contract
    error InvalidPirateEntity(address);

    /// @notice Ship combat stats require a pirate captain
    error MissingPirateEntity();

    /// @notice Ship attacks can only be initiated by token owner
    error NotOwner(uint256 entityId);

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * @dev Check if ship is open to attack
     * @return boolean If the ship can be attacked
     */
    function canBeAttacked(
        uint256,
        uint256[] calldata
    ) external pure override returns (bool) {
        // For now, ships cannot be attacked -- PVP coming soon TM.
        return false;
    }

    /**
     * @dev Check if ship is capable of attacking
     * @param entityId A packed tokenId and Address of an NFT
     * @param caller address of msg.sender : used for checking if caller is owner of entityId & overloads
     * @param overloads An optional array of overload NFTs (if there is an another NFT on the boat)
     * @return boolean If the ship can attack
     */
    function canAttack(
        address caller,
        uint256 entityId,
        uint256[] calldata overloads
    ) external view override returns (bool) {
        if (overloads.length == 0) {
            revert MissingPirateEntity();
        }

        // Extract contract address and token ID from pirate
        (address contractAddress, uint256 tokenId) = EntityLibrary
            .entityToToken(overloads[0]);

        // Check NFT is a pirate (Gen0 or Gen1)
        if (
            IsPirateComponent(
                _gameRegistry.getComponent(IS_PIRATE_COMPONENT_ID)
            ).getValue(overloads[0]) == false
        ) {
            revert InvalidPirateEntity(contractAddress);
        }

        // Check pirate NFT owned by caller
        if (caller != IERC721(contractAddress).ownerOf(tokenId)) {
            revert NotOwner(overloads[0]);
        }

        // Extract contract address and token ID from entityId
        (contractAddress, tokenId) = EntityLibrary.entityToToken(entityId);

        if (contractAddress != _getSystem(SHIP_NFT_ID)) {
            revert InvalidShipEntity();
        }

        // Check ship NFT owned by caller
        if (caller != IShipNFT(contractAddress).ownerOf(tokenId)) {
            revert NotOwner(entityId);
        }

        return true;
    }
}
