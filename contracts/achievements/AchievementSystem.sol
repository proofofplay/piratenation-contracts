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

    /// @notice Counter for the last achievement id that was minted.
    uint256 public achievementsIssued;

    /** ERRORS **/

    /// @notice Achievement not found in templates
    error InvalidTemplateId(uint256 missingTemplateId);

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

        ++achievementsIssued;
        uint256 newAchievementTokenId = achievementsIssued;

        achievementNFT.mint(account, newAchievementTokenId);

        tokenTemplateSystem.setTemplate(
            address(achievementNFT),
            newAchievementTokenId,
            templateId
        );

        for (uint256 idx; idx < traitIds.length; ++idx) {
            traitsProvider.setTraitString(
                address(achievementNFT),
                newAchievementTokenId,
                traitIds[idx],
                traitValues[idx]
            );
        }

        return newAchievementTokenId;
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
