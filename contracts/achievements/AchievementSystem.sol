// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";

import "../GameRegistryConsumerUpgradeable.sol";

import {MANAGER_ROLE} from "../Constants.sol";
import {ID} from "./IAchievementSystem.sol";
import {IAchievementNFT, ID as ACHIEVEMENT_NFT_ID} from "../tokens/achievementnft/IAchievementNFT.sol";
import {ITraitsProvider, ID as TRAITS_PROVIDER_ID} from "../interfaces/ITraitsProvider.sol";
import {ITokenTemplateSystem, ID as TOKEN_TEMPLATE_SYSTEM_ID} from "../tokens/ITokenTemplateSystem.sol";

contract AchievementSystem is GameRegistryConsumerUpgradeable {
    /** MEMBERS **/

    struct BatchMigrateFields {
        address account;
        uint256 templateId;
        uint256 traitId;
        uint256 tokenId;
        string traitValue;
    }

    /// @notice Counter for the last achievement id that was minted.
    uint256 public achievementsIssued;

    /** ERRORS **/

    /// @notice Achievement not found in templates
    error InvalidTemplateId(uint256 missingTemplateId);

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
     * Grants an achievement to a player
     *
     * @param account       Address of the account to mint to
     * @param templateId    NFT template tokenId of achievement to mint
     * @param traitIds      Metadata trait ids to set on the achievement
     * @param traitValues   Metadata trait values to set on the achievement
     * @return              The tokenId of the newly minted achievement
     */
    function grantAchievement(
        address account,
        uint256 templateId,
        uint256[] calldata traitIds,
        string[] calldata traitValues
    ) external onlyRole(MANAGER_ROLE) whenNotPaused returns (uint256) {
        IAchievementNFT achievementNFT = IAchievementNFT(
            _getSystem(ACHIEVEMENT_NFT_ID)
        );

        ITokenTemplateSystem tokenTemplateSystem = ITokenTemplateSystem(
            _getSystem(TOKEN_TEMPLATE_SYSTEM_ID)
        );

        ITraitsProvider traitsProvider = _traitsProvider();

        if (!tokenTemplateSystem.exists(templateId)) {
            revert InvalidTemplateId(templateId);
        }

        achievementsIssued++;

        achievementNFT.mint(account, achievementsIssued);

        tokenTemplateSystem.setTemplate(
            address(achievementNFT),
            achievementsIssued,
            templateId
        );

        for (uint256 idx; idx < traitIds.length; ++idx) {
            traitsProvider.setTraitString(
                address(achievementNFT),
                achievementsIssued,
                traitIds[idx],
                traitValues[idx]
            );
        }

        return achievementsIssued;
    }

    /**
     * Batch grant achievements
     */
    function batchGrantAchievements(
        address[] calldata accounts,
        uint256[] calldata templateIds,
        uint256[] calldata traitIds,
        string[] calldata traitValues
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        if (
            accounts.length != templateIds.length ||
            accounts.length != traitIds.length ||
            accounts.length != traitValues.length
        ) {
            revert InvalidParameters();
        }
        IAchievementNFT achievementNFT = IAchievementNFT(
            _getSystem(ACHIEVEMENT_NFT_ID)
        );

        ITokenTemplateSystem tokenTemplateSystem = ITokenTemplateSystem(
            _getSystem(TOKEN_TEMPLATE_SYSTEM_ID)
        );

        ITraitsProvider traitsProvider = _traitsProvider();

        for (uint256 i = 0; i < accounts.length; i++) {
            if (!tokenTemplateSystem.exists(templateIds[i])) {
                revert InvalidTemplateId(templateIds[i]);
            }

            achievementsIssued++;
            uint256 newAchievementTokenId = achievementsIssued;
            achievementNFT.mint(accounts[i], newAchievementTokenId);
            tokenTemplateSystem.setTemplate(
                address(achievementNFT),
                newAchievementTokenId,
                templateIds[i]
            );
            traitsProvider.setTraitString(
                address(achievementNFT),
                newAchievementTokenId,
                traitIds[i],
                traitValues[i]
            );
        }
    }

    /**
     * Batch migrate achievements
     */
    function batchMigrateGrantAchievements(
        BatchMigrateFields[] calldata fields
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        if (fields.length == 0) {
            revert InvalidParameters();
        }
        IAchievementNFT achievementNFT = IAchievementNFT(
            _getSystem(ACHIEVEMENT_NFT_ID)
        );

        ITokenTemplateSystem tokenTemplateSystem = ITokenTemplateSystem(
            _getSystem(TOKEN_TEMPLATE_SYSTEM_ID)
        );

        ITraitsProvider traitsProvider = _traitsProvider();

        for (uint256 i = 0; i < fields.length; i++) {
            if (!tokenTemplateSystem.exists(fields[i].templateId)) {
                revert InvalidTemplateId(fields[i].templateId);
            }

            achievementNFT.mint(fields[i].account, fields[i].tokenId);
            tokenTemplateSystem.setTemplate(
                address(achievementNFT),
                fields[i].tokenId,
                fields[i].templateId
            );
            traitsProvider.setTraitString(
                address(achievementNFT),
                fields[i].tokenId,
                fields[i].traitId,
                fields[i].traitValue
            );
        }
    }

    /**
     * Adjusts the counter of achievement token ids to a given value
     *
     * @param newValue      New value to set the counter to
     */
    function adjustCounter(uint256 newValue) external onlyRole(MANAGER_ROLE) {
        achievementsIssued = newValue;
    }
}
