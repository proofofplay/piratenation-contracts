// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {ITokenTemplateSystem, ID as TOKEN_TEMPLATE_SYSTEM_ID} from "../tokens/ITokenTemplateSystem.sol";
import {BOSS_TYPE_TRAIT_ID, CURRENT_HEALTH_TRAIT_ID, HEALTH_TRAIT_ID, MINTER_ROLE} from "../Constants.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.bossspawn"));

/**
 * @title BossSpawn
 *
 * Spawn Boss
 */
contract BossSpawn is GameRegistryConsumerUpgradeable {
    error InvalidBoss(uint256 templateId);

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * Spawn Boss
     * @dev Could make this a batch spawn? takes in uint256[]
     * @param templateId is ID from SoT and also Boss ID
     */
    function spawnBoss(uint256 templateId) external onlyRole(MINTER_ROLE) {
        ITokenTemplateSystem tokenTemplateSystem = ITokenTemplateSystem(
            _getSystem(TOKEN_TEMPLATE_SYSTEM_ID)
        );

        if (!tokenTemplateSystem.exists(templateId)) {
            revert InvalidBoss(templateId);
        }

        // Set World Boss data from SoT TokenTemplate
        tokenTemplateSystem.setTemplate(address(this), templateId, templateId);

        // Check that is a boss template
        if (
            tokenTemplateSystem.hasTrait(
                address(this),
                templateId,
                BOSS_TYPE_TRAIT_ID
            ) == false
        ) {
            revert InvalidBoss(templateId);
        }

        int256 maxHealth = tokenTemplateSystem.getTraitInt256(
            address(this),
            templateId,
            HEALTH_TRAIT_ID
        );
        _traitsProvider().setTraitUint256(
            address(this),
            templateId,
            CURRENT_HEALTH_TRAIT_ID,
            SafeCast.toUint256(maxHealth)
        );
    }
}
