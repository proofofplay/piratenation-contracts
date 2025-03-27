// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {LootArrayComponentLibrary} from "../loot/LootArrayComponentLibrary.sol";

import {AccountSkillsXpGrantedComponent, Layout as AccountSkillsXpGrantedLayout, ID as ACCOUNT_SKILLS_XP_GRANTED_COMPONENT_ID} from "../generated/components/AccountSkillsXpGrantedComponent.sol";
import {AccountSkillRequirementsComponent, Layout as AccountSkillRequirementsLayout, ID as ACCOUNT_SKILL_REQUIREMENTS_COMPONENT_ID} from "../generated/components/AccountSkillRequirementsComponent.sol";
import {AccountXpTrackerComponent, ID as ACCOUNT_XP_TRACKER_COMPONENT_ID} from "../generated/components/AccountXpTrackerComponent.sol";
import {LootEntityArrayComponent, Layout as LootEntityArrayLayout, ID as LOOT_ENTITY_ARRAY_COMPONENT_ID} from "../generated/components/LootEntityArrayComponent.sol";
import {LootSetArrayComponent, ID as LOOT_SET_ARRAY_COMPONENT_ID} from "../generated/components/LootSetArrayComponent.sol";
import {Uint256ArrayComponent, ID as UINT256_ARRAY_COMPONENT_ID} from "../generated/components/Uint256ArrayComponent.sol";
import {Uint256Component, ID as UINT256_COMPONENT_ID} from "../generated/components/Uint256Component.sol";
import {ILootSystemV2, ID as LOOT_SYSTEM_V2_ID} from "../loot/ILootSystemV2.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {IAccountXpSystem, BASE_ACCOUNT_SKILL_ID, ID} from "./IAccountXpSystem.sol";
import {ITradeLicenseSystem, ID as TRADE_LICENSE_ID} from "./ITradeLicenseSystem.sol";

// GameGlobals key for TradeLicense AccountXp threshold
uint256 constant TRADE_LICENSE_THRESHOLD = uint256(
    keccak256("game.piratenation.global.trade_license_threshold")
);

/**
 * @title AccountXpSystem
 */
contract AccountXpSystem is IAccountXpSystem, GameRegistryConsumerUpgradeable {
    /** ERRORS */

    /// @notice Error when invalid zero inputs used
    error InvalidInputs();

    /// @notice Invalid skill entity id
    error InvalidAccountSkillEntity(uint256 entity);

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /** SETTERS */
    /**
     * @dev Grant Account Xp to an entity for a specific skill
     * @param entity Entity to grant xp to
     * @param amount Amount of xp to grant
     * @param skillEntity Entity of the account skill
     */
    function grantAccountSkillXp(
        uint256 entity,
        uint256 amount,
        uint256 skillEntity
    )
        public
        override
        nonReentrant
        whenNotPaused
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
    {
        _grantAccountSkillXp(entity, amount, skillEntity);
    }

    /**
     *  Grant Account Xp from an entity
     * @param accountEntity  EntityId of the account
     * @param entityGranting EntityId of the entity granting the xp
     * @param numSuccesses Number of successes
     * @param numFailures Number of failures
     */
    function grantAccountSkillsXp(
        uint256 accountEntity,
        uint256 entityGranting,
        uint256 numSuccesses,
        uint256 numFailures
    )
        public
        override
        nonReentrant
        whenNotPaused
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
    {
        AccountSkillsXpGrantedLayout
            memory accountSkillsXpGrantedLayout = AccountSkillsXpGrantedComponent(
                _gameRegistry.getComponent(
                    ACCOUNT_SKILLS_XP_GRANTED_COMPONENT_ID
                )
            ).getLayoutValue(entityGranting);
        // loop through accountSkillsXpGrantedLayout.accountSkillEntities
        for (
            uint256 i = 0;
            i < accountSkillsXpGrantedLayout.accountSkillEntities.length;
            i++
        ) {
            uint256 amount = 0;
            if (numSuccesses > 0) {
                amount +=
                    accountSkillsXpGrantedLayout.successAmount[i] *
                    numSuccesses;
            }
            if (numFailures > 0) {
                amount +=
                    accountSkillsXpGrantedLayout.failAmount[i] *
                    numFailures;
            }
            if (amount > 0) {
                _grantAccountSkillXp(
                    accountEntity,
                    amount,
                    accountSkillsXpGrantedLayout.accountSkillEntities[i]
                );
            }
        }
    }

    /**
     * @dev Get the account xp for an entity for a specific skill
     * @param accountEntity EntityId of the account
     */
    function getAccountSkillXp(
        uint256 accountEntity,
        uint256 skillEntity
    ) public view override returns (uint256) {
        // Get current account xp for entityToGrant
        AccountXpTrackerComponent accountXpTracker = AccountXpTrackerComponent(
            _gameRegistry.getComponent(ACCOUNT_XP_TRACKER_COMPONENT_ID)
        );
        // Get current account xp and return
        uint256 currentXp = accountXpTracker
            .getLayoutValue(
                _getAccountSkillProgressEntity(accountEntity, skillEntity)
            )
            .currentAccountXp;
        return currentXp;
    }

    /**
     * @dev Get the current account level for an entity for specific skill
     * @param accountEntity EntityId of the account
     * @param skillEntity Entity of the account skill
     */
    function getAccountSkillLevel(
        uint256 accountEntity,
        uint256 skillEntity
    ) public view override returns (uint256) {
        uint256 currentXp = getAccountSkillXp(accountEntity, skillEntity);
        return _convertAccountSkillXpToLevel(currentXp, skillEntity);
    }

    /**
     * @dev Convert account xp to level for a specific skill
     * @param accountXp Account xp to convert
     * @param skillEntity Entity of the account skill
     */
    function convertAccountSkillXpToLevel(
        uint256 accountXp,
        uint256 skillEntity
    ) public view override returns (uint256) {
        return _convertAccountSkillXpToLevel(accountXp, skillEntity);
    }

    /**
     * @dev Does the account have the required skills from an entity with requirements
     * @param accountEntity EntityId of the account
     * @param entityWithRequirements EntityId of the entity with requirements AccountSkillRequirementsComponent
     */
    function hasRequiredSkills(
        uint256 accountEntity,
        uint256 entityWithRequirements
    ) external view override returns (bool) {
        AccountSkillRequirementsLayout
            memory accountSkillRequirementsLayout = AccountSkillRequirementsComponent(
                _gameRegistry.getComponent(
                    ACCOUNT_SKILL_REQUIREMENTS_COMPONENT_ID
                )
            ).getLayoutValue(entityWithRequirements);

        for (
            uint256 i = 0;
            i < accountSkillRequirementsLayout.accountSkillEntities.length;
            i++
        ) {
            uint256 requiredSkillEntity = accountSkillRequirementsLayout
                .accountSkillEntities[i];
            uint256 requiredSkillLevel = accountSkillRequirementsLayout
                .skillLevelRequirements[i];
            uint256 accountSkillLevel = getAccountSkillLevel(
                accountEntity,
                requiredSkillEntity
            );
            if (accountSkillLevel < requiredSkillLevel) {
                return false;
            }
        }
        return true;
    }

    /** INTERNAL **/

    /**
     * @dev Convert account xp to level for a specific skill
     * @param accountXp Account xp to convert
     * @param skillEntity Entity of the account skill
     */
    function _convertAccountSkillXpToLevel(
        uint256 accountXp,
        uint256 skillEntity
    ) internal view returns (uint256) {
        Uint256ArrayComponent uint256ArrayComponent = Uint256ArrayComponent(
            _gameRegistry.getComponent(UINT256_ARRAY_COMPONENT_ID)
        );

        uint256[] memory levelThresholds = uint256ArrayComponent.getValue(
            skillEntity
        );
        uint256 currentLevel = 0;
        for (uint256 i = 0; i < levelThresholds.length; i++) {
            if (accountXp >= levelThresholds[i]) {
                currentLevel = i + 1;
            }
        }
        return currentLevel;
    }

    /**
     * @dev Checks if an entity qualifies for a trade license and grants if needed
     * @param accountEntity EntityId of the account
     * @param newAccountXp New account xp
     */
    function _checkIfQualifiesForTradeLicense(
        uint256 accountEntity,
        uint256 newAccountXp
    ) internal {
        Uint256Component uint256Component = Uint256Component(
            _gameRegistry.getComponent(UINT256_COMPONENT_ID)
        );

        // Get account xp threshold to obtain TradeLicense
        uint256 tradeLicenseThreshold = uint256Component.getValue(
            TRADE_LICENSE_THRESHOLD
        );
        // Check if new account xp level qualifies for TradeLicense and grant if needed
        if (
            _convertAccountSkillXpToLevel(
                newAccountXp,
                BASE_ACCOUNT_SKILL_ID
            ) >= tradeLicenseThreshold
        ) {
            ITradeLicenseSystem tradeLicenseSystem = ITradeLicenseSystem(
                _getSystem(TRADE_LICENSE_ID)
            );
            address account = EntityLibrary.entityToAddress(accountEntity);
            // Check if account already has a trade license
            if (tradeLicenseSystem.checkHasTradeLicense(account) == false) {
                tradeLicenseSystem.grantTradeLicense(account);
            }
        }
    }

    /**
     * @dev Grants loot for each new level reached
     * @param accountEntity EntityId of the account
     * @param skillEntity Entity of the account skill
     * @param currentAccountXp Current account xp
     * @param newAccountXp New account xp
     */
    function _grantLootPerLevel(
        uint256 accountEntity,
        uint256 skillEntity,
        uint256 currentAccountXp,
        uint256 newAccountXp
    ) internal {
        uint256 currentAccountLevel = _convertAccountSkillXpToLevel(
            currentAccountXp,
            skillEntity
        );
        uint256 newAccountLevel = _convertAccountSkillXpToLevel(
            newAccountXp,
            skillEntity
        );
        // Check if next level has been reached
        if (newAccountLevel > currentAccountLevel) {
            LootSetArrayComponent lootSetArrayComponent = LootSetArrayComponent(
                _gameRegistry.getComponent(LOOT_SET_ARRAY_COMPONENT_ID)
            );
            // Get LootSetArray using system ID
            uint256[] memory lootSetEntityIds = lootSetArrayComponent.getValue(
                skillEntity
            );
            // Grant rewards if any
            if (lootSetEntityIds.length > 0) {
                address account = EntityLibrary.entityToAddress(accountEntity);
                address lootEntityArrayComponentAddress = _gameRegistry
                    .getComponent(LOOT_ENTITY_ARRAY_COMPONENT_ID);
                ILootSystemV2.Loot[] memory lootArray;
                ILootSystemV2 lootSystem = ILootSystemV2(
                    _getSystem(LOOT_SYSTEM_V2_ID)
                );
                // Grant loot for each new level after the current level
                for (
                    uint256 i = currentAccountLevel;
                    i < newAccountLevel;
                    i++
                ) {
                    uint256 levelToGrantFor = i + 1;
                    uint256 lootSetEntity = lootSetEntityIds[levelToGrantFor];
                    if (lootSetEntity != 0) {
                        lootArray = LootArrayComponentLibrary
                            .convertLootEntityArrayToLoot(
                                lootEntityArrayComponentAddress,
                                lootSetEntity
                            );
                        if (lootArray.length > 0) {
                            lootSystem.grantLoot(account, lootArray);
                        }
                    }
                }
            }
        }
    }

    /**
     *  Grant Account Xp to an entity for a specific skill
     * @param entity Entity to grant xp to
     * @param amount Amount of xp to grant
     * @param skillEntity Entity of the account skill
     */
    function _grantAccountSkillXp(
        uint256 entity,
        uint256 amount,
        uint256 skillEntity
    ) internal {
        // Check valid inputs
        if (entity == 0 || amount == 0) {
            revert InvalidInputs();
        }

        // Get current account xp for entityToGrant
        AccountXpTrackerComponent accountXpTracker = AccountXpTrackerComponent(
            _gameRegistry.getComponent(ACCOUNT_XP_TRACKER_COMPONENT_ID)
        );

        Uint256ArrayComponent uint256ArrayComponent = Uint256ArrayComponent(
            _gameRegistry.getComponent(UINT256_ARRAY_COMPONENT_ID)
        );

        // Get entity that tracks account xp progress for this skill
        uint256 accountSkillProgressEntity = _getAccountSkillProgressEntity(
            entity,
            skillEntity
        );

        // Get current account xp and return if already at max threshold
        uint256 currentXp = accountXpTracker
            .getLayoutValue(accountSkillProgressEntity)
            .currentAccountXp;

        uint256[] memory levelThresholds = uint256ArrayComponent.getValue(
            skillEntity
        );
        uint256 maxXpAmount = levelThresholds[levelThresholds.length - 1];
        // Do not grant more xp if max already reached
        if (currentXp >= maxXpAmount) {
            return;
        }
        // Calculate new account xp and grant trade license if applicable and if needed
        uint256 newAccountXp = currentXp + amount;
        if (newAccountXp > maxXpAmount) {
            newAccountXp = maxXpAmount;
        }
        // Grant loot if a new level has been reached
        _grantLootPerLevel(entity, skillEntity, currentXp, newAccountXp);
        // Check if entity qualifies for a trade license and grant if needed
        if (skillEntity == BASE_ACCOUNT_SKILL_ID) {
            _checkIfQualifiesForTradeLicense(entity, newAccountXp);
        }
        // Add the action xp reward amount to the current account xp
        accountXpTracker.setValue(accountSkillProgressEntity, newAccountXp);
    }

    /**
     * @dev Get the account skill progress entity
     * @param entity EntityId of the account
     * @param skillEntity Entity of the account skill
     */
    function _getAccountSkillProgressEntity(
        uint256 entity,
        uint256 skillEntity
    ) internal pure returns (uint256) {
        if (skillEntity == BASE_ACCOUNT_SKILL_ID) {
            return entity;
        }
        uint256 entityId = uint256(
            keccak256(abi.encodePacked(entity, skillEntity))
        );
        return entityId;
    }
}
