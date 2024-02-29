// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {GAME_LOGIC_CONTRACT_ROLE, ELEMENTAL_AFFINITY_TRAIT_ID} from "../Constants.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {BattleLibrary} from "./BattleLibrary.sol";
import {PirateLibrary} from "../libraries/PirateLibrary.sol";
import {ShipEquipment, ID as SHIP_EQUIPMENT_ID} from "../equipment/ShipEquipment.sol";
import {ID as PIRATE_NFT_ID} from "../tokens/PirateNFTL2.sol";
import {ID as STARTER_PIRATE_NFT_ID} from "../tokens/starterpiratenft/StarterPirateNFT.sol";
import {IShipNFT} from "../tokens/shipnft/IShipNFT.sol";
import {ID as SHIP_NFT_ID} from "../tokens/shipnft/ShipNFT.sol";
import {IGameGlobals, ID as GAME_GLOBALS_ID} from "../gameglobals/IGameGlobals.sol";

import {CombatStats, Combatable} from "./Combatable.sol";
import {CoreMoveSystem, ID as CORE_MOVE_SYSTEM_ID} from "./CoreMoveSystem.sol";

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
     * @dev Calculates ships combat stats from the nft, template, equipment, and boarded pirate
     * @param entityId A packed tokenId and Address of a Ship NFT
     * @param moveId A Uint of what the move the Attack is doing
     * @param overloads An optional array of overload NFTs (if there is an another NFT on the boat)
     * @return CombatStats An enum returning the stats that can be used for combat.
     */
    function getCombatStats(
        uint256 entityId,
        uint256,
        uint256 moveId,
        uint256[] calldata overloads
    ) external view override returns (CombatStats memory) {
        if (overloads.length != 1) {
            revert MissingPirateEntity();
        }

        (address pirateContract, uint256 pirateTokenId) = EntityLibrary
            .entityToToken(overloads[0]);

        CombatStats memory stats = _getCombatStats(entityId);

        // Retrieve combat stat modifiers from move system
        int256[] memory moveMods = CoreMoveSystem(
            _getSystem(CORE_MOVE_SYSTEM_ID)
        ).getCombatModifiers(moveId);

        // Retrieve combat stat modifiers from equipment
        int256[] memory equipmentMods = ShipEquipment(
            _getSystem(SHIP_EQUIPMENT_ID)
        ).getCombatModifiers(entityId);

        // Apply expertise modifiers
        stats = BattleLibrary.applyExpertiseToCombatStats(
            _traitsProvider(),
            IGameGlobals(_getSystem(GAME_GLOBALS_ID)),
            stats,
            overloads[0]
        );

        return
            CombatStats({
                damage: stats.damage +
                    int64(moveMods[0]) +
                    int64(equipmentMods[0]),
                evasion: stats.evasion +
                    int64(moveMods[1]) +
                    int64(equipmentMods[1]),
                speed: stats.speed +
                    int64(moveMods[2]) +
                    int64(equipmentMods[2]),
                accuracy: stats.accuracy +
                    int64(moveMods[3]) +
                    int64(equipmentMods[3]),
                // For now, we cannot modify combat stat health with moves
                // This requires game design decisions before it is implemented
                health: stats.health,
                // Get affinity from Pirate captain
                affinity: uint64(
                    _traitsProvider().getTraitUint256(
                        pirateContract,
                        pirateTokenId,
                        ELEMENTAL_AFFINITY_TRAIT_ID
                    )
                ),
                move: uint64(moveId)
            });
    }

    /**
     * @dev Decrease the current_health trait of entityId
     * @param entityId A packed tokenId and Address of an NFT
     * @param amount The damage that should be deducted from an NFT's health
     * @return newHealth The health left after damage is taken
     */
    function decreaseHealth(
        uint256 entityId,
        uint256 amount
    ) external override onlyRole(GAME_LOGIC_CONTRACT_ROLE) returns (uint256) {
        return _decreaseHealth(entityId, amount);
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
            PirateLibrary.isPirateNFT(
                _gameRegistry,
                _traitsProvider(),
                contractAddress,
                tokenId
            ) == false
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

        return !_isHealthZero(contractAddress, tokenId);
    }
}
