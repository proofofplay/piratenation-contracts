// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {LootArrayComponentLibrary} from "../loot/LootArrayComponentLibrary.sol";

import {AccountXpTrackerComponent, ID as ACCOUNT_XP_TRACKER_COMPONENT_ID} from "../generated/components/AccountXpTrackerComponent.sol";
import {LootArrayComponent, Layout as LootArrayLayout, ID as LOOT_ARRAY_COMPONENT_ID} from "../generated/components/LootArrayComponent.sol";
import {LootSetArrayComponent, ID as LOOT_SET_ARRAY_COMPONENT_ID} from "../generated/components/LootSetArrayComponent.sol";
import {Uint256ArrayComponent, ID as UINT256_ARRAY_COMPONENT_ID} from "../generated/components/Uint256ArrayComponent.sol";
import {Uint256Component, ID as UINT256_COMPONENT_ID} from "../generated/components/Uint256Component.sol";
import {ILootSystem} from "../loot/ILootSystem.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {IAccountXpSystem, ID} from "./IAccountXpSystem.sol";
import {ITradeLicenseSystem, ID as TRADE_LICENSE_ID} from "./ITradeLicenseSystem.sol";

// GameGlobals key for TradeLicense AccountXp threshold
uint256 constant TRADE_LICENSE_THRESHOLD = uint256(
    keccak256("game.piratenation.global.trade_license_threshold")
);

// GameGlobals key for Account Xp thresholds for each level
uint256 constant ACCOUNT_XP_THRESHOLDS = uint256(
    keccak256("game.piratenation.global.account_xp_thresholds")
);

/**
 * @title AccountXpSystem
 */
contract AccountXpSystem is IAccountXpSystem, GameRegistryConsumerUpgradeable {
    /** ERRORS */

    /// @notice Error when invalid zero inputs used
    error InvalidInputs();

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
     * @dev Grant Account Xp to an entity
     * @param entity Entity to grant xp to
     * @param amount Amount of xp to grant
     */
    function grantAccountXp(
        uint256 entity,
        uint256 amount
    )
        public
        override
        nonReentrant
        whenNotPaused
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
    {
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

        // Get current account xp and return if already at max threshold
        uint256 currentXp = accountXpTracker
            .getLayoutValue(entity)
            .currentAccountXp;
        uint256[] memory levelThresholds = uint256ArrayComponent.getValue(ACCOUNT_XP_THRESHOLDS);
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
        _grantLootPerLevel(entity, currentXp, newAccountXp);
        // Check if entity qualifies for a trade license and grant if needed
        _checkIfQualifiesForTradeLicense(entity, newAccountXp);
        // Add the action xp reward amount to the current account xp
        accountXpTracker.setValue(entity, newAccountXp);
    }

    /**
     * @dev Get the account xp for an entity
     * @param accountEntity EntityId of the account
     */
    function getAccountXp(
        uint256 accountEntity
    ) public view override returns (uint256) {
        // Get current account xp for entityToGrant
        AccountXpTrackerComponent accountXpTracker = AccountXpTrackerComponent(
            _gameRegistry.getComponent(ACCOUNT_XP_TRACKER_COMPONENT_ID)
        );
        // Get current account xp and return
        uint256 currentXp = accountXpTracker
            .getLayoutValue(accountEntity)
            .currentAccountXp;
        return currentXp;
    }

    /**
     * @dev Get the current account level for an entity
     * @param accountEntity EntityId of the account
     */
    function getPlayerAccountLevel(
        uint256 accountEntity
    ) public view returns (uint256) {
        uint256 currentXp = getAccountXp(accountEntity);
        return _convertAccountXpToLevel(currentXp);
    }

    /**
     * @dev Convert account xp to level
     * @param accountXp Account xp to convert
     */
    function convertAccountXpToLevel(
        uint256 accountXp
    ) public view returns (uint256) {
        return _convertAccountXpToLevel(accountXp);
    }

    /** INTERNAL **/

    /**
     * @dev Convert account xp to level
     * @param accountXp Account xp to convert
     */
    function _convertAccountXpToLevel(
        uint256 accountXp
    ) internal view returns (uint256) {
        Uint256ArrayComponent uint256ArrayComponent = Uint256ArrayComponent(
            _gameRegistry.getComponent(UINT256_ARRAY_COMPONENT_ID)
        );

        uint256[] memory levelThresholds = uint256ArrayComponent.getValue(ACCOUNT_XP_THRESHOLDS);
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
     */
    function _checkIfQualifiesForTradeLicense(
        uint256 accountEntity,
        uint256 newAccountXp
    ) internal {

        Uint256Component uint256Component = Uint256Component(
            _gameRegistry.getComponent(UINT256_COMPONENT_ID)
        );

        // Get account xp threshold to obtain TradeLicense
        uint256 tradeLicenseThreshold = uint256Component.getValue(TRADE_LICENSE_THRESHOLD);
        // Check if new account xp level qualifies for TradeLicense and grant if needed
        if (_convertAccountXpToLevel(newAccountXp) >= tradeLicenseThreshold) {
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
     */
    function _grantLootPerLevel(
        uint256 accountEntity,
        uint256 currentAccountXp,
        uint256 newAccountXp
    ) internal {
        uint256 currentAccountLevel = _convertAccountXpToLevel(
            currentAccountXp
        );
        uint256 newAccountLevel = _convertAccountXpToLevel(newAccountXp);
        // Check if next level has been reached
        if (newAccountLevel > currentAccountLevel) {
            LootSetArrayComponent lootSetArrayComponent = LootSetArrayComponent(
                _gameRegistry.getComponent(LOOT_SET_ARRAY_COMPONENT_ID)
            );
            // Get LootSetArray using system ID
            uint256[] memory lootSetEntityIds = lootSetArrayComponent.getValue(
                ID
            );
            // No reward loots have been set
            if (lootSetEntityIds.length == 0) {
                return;
            }
            address account = EntityLibrary.entityToAddress(accountEntity);
            address lootArrayComponentAddress = _gameRegistry.getComponent(
                LOOT_ARRAY_COMPONENT_ID
            );
            ILootSystem.Loot[] memory lootArray;
            ILootSystem lootSystem = _lootSystem();
            // Grant loot for each new level after the current level
            for (uint256 i = currentAccountLevel; i < newAccountLevel; i++) {
                uint256 levelToGrantFor = i + 1;
                uint256 lootSetEntity = lootSetEntityIds[levelToGrantFor];
                if (lootSetEntity != 0) {
                    lootArray = LootArrayComponentLibrary
                        .convertLootArrayToLootSystem(
                            lootArrayComponentAddress,
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
