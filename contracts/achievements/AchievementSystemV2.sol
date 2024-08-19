// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";

import {MANAGER_ROLE} from "../Constants.sol";
import {IAchievementNFT, ID as ACHIEVEMENT_NFT_ID} from "../tokens/achievementnft/IAchievementNFT.sol";

import {MixinComponent, ID as MIXIN_COMPONENT_ID} from "../generated/components/MixinComponent.sol";
import {MintCounterComponent, ID as MINT_COUNTER_COMPONENT_ID} from "../generated/components/MintCounterComponent.sol";
import {AchievedAtComponent, ID as ACHIEVED_AT_COMPONENT_ID} from "../generated/components/AchievedAtComponent.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {TokenIdLibrary} from "../core/TokenIdLibrary.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.achievementsystem.v2")
);

contract AchievementSystemV2 is GameRegistryConsumerUpgradeable {
    /** MEMBERS **/

    struct BatchMigrateFields {
        address account;
        uint256 mixinId;
        uint256 tokenId;
        string achievedAtDate;
    }

    /** ERRORS **/

    /// @notice Invalid mixin id
    error InvalidMixinId(uint256 missingTemplateId);

    error InvalidParameters();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * Updates the current nft id count
     * @param newCount      New count to set
     */
    function updateCurrentAchievementCount(
        uint256 newCount
    ) external onlyRole(MANAGER_ROLE) {
        MintCounterComponent mintCounterComponent = MintCounterComponent(
            _gameRegistry.getComponent(MINT_COUNTER_COMPONENT_ID)
        );
        mintCounterComponent.setValue(ID, newCount);
    }

    /**
     * Grants an achievement to a player
     *
     * @param account       Address of the account to mint to
     * @param mixinId       NFT template tokenId of achievement to mint
     * @param achievedAtDate   Metadata trait values to set on the achievement
     */
    function grantAchievement(
        address account,
        uint256 mixinId,
        string calldata achievedAtDate
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        IAchievementNFT achievementNFT = IAchievementNFT(
            _getSystem(ACHIEVEMENT_NFT_ID)
        );

        // Get and set counter for NFT token id
        MintCounterComponent mintCounterComponent = MintCounterComponent(
            _gameRegistry.getComponent(MINT_COUNTER_COMPONENT_ID)
        );
        uint256 currentId = mintCounterComponent.getValue(ID);
        currentId++;

        uint96 tokenId = TokenIdLibrary.generateTokenId(currentId);
        uint256 entity = EntityLibrary.tokenToEntity(
            address(achievementNFT),
            tokenId
        );

        // Mint the achievement
        achievementNFT.mint(account, tokenId);
        // Increment the counter
        mintCounterComponent.setValue(ID, currentId);

        // Set the mixin component for the achievement
        MixinComponent mixinComponent = MixinComponent(
            _gameRegistry.getComponent(MIXIN_COMPONENT_ID)
        );
        _setupAchievement(mixinComponent, mixinId, entity, achievedAtDate);
    }

    /**
     * Batch grant achievements
     */
    function batchGrantAchievements(
        address[] calldata accounts,
        uint256[] calldata mixinIds,
        string[] calldata achievedAtDates
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        if (
            accounts.length != mixinIds.length ||
            accounts.length != achievedAtDates.length
        ) {
            revert InvalidParameters();
        }
        IAchievementNFT achievementNFT = IAchievementNFT(
            _getSystem(ACHIEVEMENT_NFT_ID)
        );

        MintCounterComponent mintCounterComponent = MintCounterComponent(
            _gameRegistry.getComponent(MINT_COUNTER_COMPONENT_ID)
        );
        uint256 currentId = mintCounterComponent.getValue(ID);

        for (uint256 i = 0; i < accounts.length; i++) {
            currentId++;
            uint96 tokenId = TokenIdLibrary.generateTokenId(currentId);
            achievementNFT.mint(accounts[i], tokenId);
            _setupAchievement(
                MixinComponent(_gameRegistry.getComponent(MIXIN_COMPONENT_ID)),
                mixinIds[i],
                EntityLibrary.tokenToEntity(address(achievementNFT), tokenId),
                achievedAtDates[i]
            );
        }

        mintCounterComponent.setValue(ID, currentId);
    }

    /**
     * Batch mint achievements with multi-chain tokenId support
     */
    function batchMintAchievements(
        BatchMigrateFields[] calldata fields
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        if (fields.length == 0) {
            revert InvalidParameters();
        }
        IAchievementNFT achievementNFT = IAchievementNFT(
            _getSystem(ACHIEVEMENT_NFT_ID)
        );

        for (uint256 i = 0; i < fields.length; i++) {
            achievementNFT.mint(fields[i].account, fields[i].tokenId);
            _setupAchievement(
                MixinComponent(_gameRegistry.getComponent(MIXIN_COMPONENT_ID)),
                fields[i].mixinId,
                EntityLibrary.tokenToEntity(
                    address(achievementNFT),
                    fields[i].tokenId
                ),
                fields[i].achievedAtDate
            );
        }
    }

    /** INTERNAL **/

    function _setupAchievement(
        MixinComponent mixinComponent,
        uint256 mixinId,
        uint256 entity,
        string calldata achievedAtDate
    ) internal {
        if (mixinId == 0) {
            revert InvalidMixinId(mixinId);
        }

        uint256[] memory mixins = new uint256[](1);
        mixins[0] = mixinId;

        mixinComponent.setValue(entity, mixins);

        // Set achieved at
        AchievedAtComponent(
            _gameRegistry.getComponent(ACHIEVED_AT_COMPONENT_ID)
        ).setValue(entity, achievedAtDate);
    }
}
