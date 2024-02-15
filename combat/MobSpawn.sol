// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {CURRENT_HEALTH_TRAIT_ID, HEALTH_TRAIT_ID, IS_MOB_TRAIT_ID, MANAGER_ROLE} from "../Constants.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {ITokenTemplateSystem, ID as TOKEN_TEMPLATE_SYSTEM_ID} from "../tokens/ITokenTemplateSystem.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.mobspawn"));

/**
 * @title MobSpawn
 */
contract MobSpawn is GameRegistryConsumerUpgradeable {
    error InvalidMob(uint256 templateId);

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * @dev Initializes a dungeon mob
     * @param templateId is ID from SoT and also mob ID
     */
    function initializeMob(uint256 templateId) external onlyRole(MANAGER_ROLE) {
        ITokenTemplateSystem tokenTemplateSystem = ITokenTemplateSystem(
            _getSystem(TOKEN_TEMPLATE_SYSTEM_ID)
        );

        if (!tokenTemplateSystem.exists(templateId)) {
            revert InvalidMob(templateId);
        }

        // Set dungeon mob data from SoT TokenTemplate
        tokenTemplateSystem.setTemplate(address(this), templateId, templateId);

        // Check that is a mob spawn
        if (
            tokenTemplateSystem.hasTrait(
                address(this),
                templateId,
                IS_MOB_TRAIT_ID
            ) == false
        ) {
            revert InvalidMob(templateId);
        }
    }
}
