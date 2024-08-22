// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ILevelSystem, ID} from "./ILevelSystem.sol";
import {IGameCurrency} from "../tokens/IGameCurrency.sol";
import {ID as GOLD_TOKEN_STRATEGY_ID} from "../tokens/goldtoken/GoldTokenStrategy.sol";
import {Uint256Component, ID as UINT256_COMPONENT_ID} from "../generated/components/Uint256Component.sol";
import {Uint256ArrayComponent, ID as UINT256_ARRAY_COMPONENT_ID} from "../generated/components/Uint256ArrayComponent.sol";
import {ICaptainSystem, ID as CAPTAIN_SYSTEM_ID} from "../captain/ICaptainSystem.sol";
import {PERCENTAGE_RANGE, GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {LevelComponent, ID as LEVEL_COMPONENT_ID} from "../generated/components/LevelComponent.sol";
import {IsPirateComponent, ID as IS_PIRATE_COMPONENT_ID} from "../generated/components/IsPirateComponent.sol";
import {XpComponent, ID as XP_COMPONENT_ID} from "../generated/components/XpComponent.sol";

import "../GameRegistryConsumerUpgradeable.sol";

// Globals used by this contract
uint256 constant TOTAL_XP_FOR_LEVEL_ID = uint256(
    keccak256("game.piratenation.global.total_xp_to_level_up")
);
uint256 constant GOLD_TO_LEVEL_UP_ID = uint256(
    keccak256("game.piratenation.global.gold_to_level_up")
);
uint256 constant CAPTAIN_XP_BONUS_PERCENT_ID = uint256(
    keccak256("game.piratenation.global.captain_xp_bonus_percent")
);
uint256 constant MAX_XP_ID = uint256(
    keccak256("game.piratenation.global.max_xp")
);
uint256 constant MAX_LEVEL_ID = uint256(
    keccak256("game.piratenation.global.max_level")
);

/// @title LevelSystem
/// Lets the player level up
contract LevelSystem is ILevelSystem, GameRegistryConsumerUpgradeable {
    /** EVENTS **/

    /// @notice Emitted when a pirates level is upgraded
    event UpgradePirateLevel(
        address indexed tokenContract,
        uint256 indexed tokenId,
        uint256 newLevel
    );

    /** ERRORS **/

    /// @notice Origin is not the owner of the specified NFT
    error NotOwner();

    /// @notice Cannot upgrade to same or lower level
    error MustUpgradeToHigherLevel();

    /// @notice Need more XP to upgrade level
    error NeedMoreXP();

    /// @notice Trying to level past max level
    error DesiredLevelExceedsMaxLevel(uint256 maxLevel, uint256 desiredLevel);

    // @notice is not a pirate
    error IsNotPirate();

    /** SETUP **/

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /** EXTERNAL **/

    /**
     * Upgrades a pirate's level based on their XP
     *
     * @param nftContract   Address of the pirate NFT contract
     * @param nftTokenId    Token id of the pirate
     * @param desiredLevel  Desired level of the pirate
     */
    function upgradePirateLevel(
        address nftContract,
        uint256 nftTokenId,
        uint32 desiredLevel
    ) external whenNotPaused nonReentrant {
        address account = _getPlayerAccount(_msgSender());

        // Owner check
        if (IERC721(nftContract).ownerOf(nftTokenId) != account) {
            revert NotOwner();
        }

        uint256 entityId = EntityLibrary.tokenToEntity(nftContract, nftTokenId);

        if (
            IsPirateComponent(
                _gameRegistry.getComponent(IS_PIRATE_COMPONENT_ID)
            ).getValue(entityId) == false
        ) {
            revert IsNotPirate();
        }

        uint256 currentLevel = LevelComponent(
            _gameRegistry.getComponent(LEVEL_COMPONENT_ID)
        ).getValue(entityId);

        if (currentLevel >= desiredLevel) {
            revert MustUpgradeToHigherLevel();
        }

        uint256[] memory xpTable = Uint256ArrayComponent(
            _gameRegistry.getComponent(UINT256_ARRAY_COMPONENT_ID)
        ).getValue(TOTAL_XP_FOR_LEVEL_ID);

        uint256 maxLevel = Uint256Component(
            _gameRegistry.getComponent(UINT256_COMPONENT_ID)
        ).getValue(MAX_LEVEL_ID);

        if (desiredLevel >= xpTable.length || desiredLevel > maxLevel) {
            revert DesiredLevelExceedsMaxLevel(xpTable.length, desiredLevel);
        }

        uint256 xpRequired = xpTable[desiredLevel];

        uint256 currentXp = XpComponent(
            _gameRegistry.getComponent(XP_COMPONENT_ID)
        ).getValue(entityId);

        if (currentXp < xpRequired) {
            revert NeedMoreXP();
        }

        // Burn the gold needed to upgrade
        _burnGold(account, currentLevel, desiredLevel);

        // Set level component value
        LevelComponent(_gameRegistry.getComponent(LEVEL_COMPONENT_ID)).setValue(
                entityId,
                desiredLevel
            );

        // Emit event
        emit UpgradePirateLevel(nftContract, nftTokenId, desiredLevel);
    }

    /**
     * Grants XP to the given token
     *
     * @param tokenContract Address of the NFT
     * @param tokenId       Id of the NFT token
     * @param amount        Amount of XP to grant
     */
    function grantXP(
        address tokenContract,
        uint256 tokenId,
        uint256 amount
    ) external onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        address owner = IERC721(tokenContract).ownerOf(tokenId);

        ICaptainSystem captainSystem = ICaptainSystem(
            _getSystem(CAPTAIN_SYSTEM_ID)
        );

        Uint256Component uint256Component = Uint256Component(
            _gameRegistry.getComponent(UINT256_COMPONENT_ID)
        );

        // Apply XP modifier for captain
        (address captainTokenContract, uint256 captainTokenId) = captainSystem
            .getCaptainNFT(owner);

        // If NFT is the captain, grant bonus XP
        if (
            captainTokenContract == tokenContract && captainTokenId == tokenId
        ) {
            amount =
                amount +
                (amount *
                    uint256Component.getValue(CAPTAIN_XP_BONUS_PERCENT_ID)) /
                PERCENTAGE_RANGE;
        }

        // Set XP component
        uint256 entityId = EntityLibrary.tokenToEntity(tokenContract, tokenId);

        // Cap XP
        uint256 maxXp = uint256Component.getValue(MAX_XP_ID);
        uint256 currentXp = XpComponent(
            _gameRegistry.getComponent(XP_COMPONENT_ID)
        ).getValue(entityId);

        amount = Math.min(maxXp - currentXp, amount);
        if (amount > 0) {
            XpComponent(_gameRegistry.getComponent(XP_COMPONENT_ID)).setValue(
                entityId,
                currentXp + amount
            );
        }
    }

    /** INTERNAL **/
    function _burnGold(
        address account,
        uint256 currentLevel,
        uint256 desiredLevel
    ) internal {
        uint256 goldRequired = 0;

        uint256[] memory goldTable = Uint256ArrayComponent(
            _gameRegistry.getComponent(UINT256_ARRAY_COMPONENT_ID)
        ).getValue(GOLD_TO_LEVEL_UP_ID);

        if (desiredLevel >= goldTable.length) {
            revert DesiredLevelExceedsMaxLevel(goldTable.length, desiredLevel);
        }

        IGameCurrency goldTokenStrategy = IGameCurrency(
            _getSystem(GOLD_TOKEN_STRATEGY_ID)
        );

        for (uint256 idx = currentLevel + 1; idx <= desiredLevel; ++idx) {
            goldRequired += goldTable[idx];
        }
        goldTokenStrategy.burn(account, goldRequired);
    }
}
