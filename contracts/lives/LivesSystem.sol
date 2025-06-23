// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.26;

import "../GameRegistryConsumerUpgradeable.sol";

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {LootArrayComponentLibrary} from "../loot/LootArrayComponentLibrary.sol";
import {IGameItems, ID as GAME_ITEMS_ID} from "../tokens/gameitems/IGameItems.sol";
import {ISubscriptionSystem, ID as SUBSCRIPTION_SYSTEM_ID, VIP_SUBSCRIPTION_TYPE} from "../subscription/ISubscriptionSystem.sol";

import {MANAGER_ROLE, GAME_NFT_CONTRACT_ROLE, GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {ID as PIRATE_NFT_ID} from "../tokens/PirateNFTL2.sol";
import {ID as STARTER_PIRATE_NFT_ID} from "../tokens/starterpiratenft/StarterPirateNFT.sol";
import {StaticEntityListComponent, ID as STATIC_ENTITY_LIST_COMPONENT_ID} from "../generated/components/StaticEntityListComponent.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {ID as LOOT_ENTITY_ARRAY_COMPONENT_ID} from "../generated/components/LootEntityArrayComponent.sol";

import {LivesPurchaseComponent, Layout as LivesPurchaseComponentLayout, ID as LIVES_PURCHASE_COMPONENT_ID} from "../generated/components/LivesPurchaseComponent.sol";
import {CounterComponent, Layout as CounterComponentLayout, ID as COUNTER_COMPONENT_ID} from "../generated/components/CounterComponent.sol";
import {Uint256Component, ID as Uint256ComponentId} from "../generated/components/Uint256Component.sol";
import {Uint256ArrayComponent, ID as Uint256ArrayComponentId} from "../generated/components/Uint256ArrayComponent.sol";
import {LivesComponent, Layout as LivesComponentLayout, ID as LIVES_COMPONENT_ID} from "../generated/components/LivesComponent.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.livessystem"));

/** ERRORS */

/// @notice Error when no pirate NFT is found
error NoPirateNFT();

/// @notice Error when a entity does not have enough lives
error NotEnoughLives(uint256 expected, uint256 actual);

/// @notice Invalid input parameters
error InvalidInputParameters();

/// @notice Not available
error NotAvailable();

/// @notice Cannot exceed max lives
error CannotExceedMaxLives();

/**
 * @title LivesSystem
 * Tracks and handles lives for a given entity through use of transform runners
 * Supports different variants of lives
 */
contract LivesSystem is GameRegistryConsumerUpgradeable {
    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * Spends lives for a given entity, used by transform runners
     *
     * @param accountAddress Account to spend lives for
     * @param livesType The type of lives to spend
     * @param amount Amount of lives to spend
     */
    function subtractLives(
        address accountAddress,
        uint256 livesType,
        uint256 amount
    ) external whenNotPaused nonReentrant onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        if (accountAddress == address(0) || amount == 0 || livesType == 0) {
            revert InvalidInputParameters();
        }
        // Get the current lives count and check if player has enough lives
        uint256 currentLives = getLivesCount(accountAddress, livesType);
        if (currentLives < amount) {
            revert NotEnoughLives(amount, currentLives);
        }
        // Subtract the lives and update the lives component
        LivesComponent(_gameRegistry.getComponent(LIVES_COMPONENT_ID)).setValue(
                EntityLibrary.accountSubEntity(accountAddress, livesType),
                currentLives - amount,
                SafeCast.toUint32(block.timestamp)
            );
    }

    /**
     * Adds lives to a given entity
     *
     * @param accountAddress Account to add lives to
     * @param livesType The type of lives to add
     * @param amount Amount of lives to add
     */
    function addLives(
        address accountAddress,
        uint256 livesType,
        uint256 amount
    ) external whenNotPaused nonReentrant onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        if (accountAddress == address(0) || amount == 0 || livesType == 0) {
            revert InvalidInputParameters();
        }
        // Get the current lives count and check if player is not exceeding max lives
        uint256 currentLives = getLivesCount(accountAddress, livesType);
        if (currentLives + amount > _maxLives(accountAddress, livesType)) {
            revert CannotExceedMaxLives();
        }
        // Add the lives and update the lives component
        LivesComponent(_gameRegistry.getComponent(LIVES_COMPONENT_ID)).setValue(
                EntityLibrary.accountSubEntity(accountAddress, livesType),
                currentLives + amount,
                SafeCast.toUint32(block.timestamp)
            );
    }

    /**
     * @param accountAddress Account to get lives for
     * @param livesType The type of lives to get
     * @return The amount of lives for the given account for the lives type specified
     */
    function getLivesCount(
        address accountAddress,
        uint256 livesType
    ) public view returns (uint256) {
        uint256 livesEntity = EntityLibrary.accountSubEntity(
            accountAddress,
            livesType
        );
        LivesComponentLayout memory livesLayout = LivesComponent(
            _gameRegistry.getComponent(LIVES_COMPONENT_ID)
        ).getLayoutValue(livesEntity);
        uint256 maxLives = _maxLives(accountAddress, livesType);
        // If no lives have been spent or the last spend was more than 1 day ago then return max lives
        if (
            livesLayout.lastSpendTimestamp == 0 ||
            (livesLayout.lastSpendTimestamp / 1 days) <
            (block.timestamp / 1 days)
        ) {
            return maxLives;
        }
        // Otherwise return the amount of lives the entity has since the last spend
        return livesLayout.lastLifeAmount;
    }

    /**
     * @dev Purchase lives, limited by the daily count
     */
    function purchaseLives(
        uint256 livesType
    ) external whenNotPaused nonReentrant {
        address account = _getPlayerAccount(_msgSender());
        // Lives packs
        uint256[] memory entityList = StaticEntityListComponent(
            _gameRegistry.getComponent(STATIC_ENTITY_LIST_COMPONENT_ID)
        ).getValue(livesType);
        if (entityList.length == 0) {
            revert NotAvailable();
        }
        // Form the entity for the player wallet and the lives type and current day
        uint256 currentDayWalletEntity = uint256(
            (
                keccak256(
                    abi.encodePacked(
                        account,
                        livesType,
                        block.timestamp / 1 days
                    )
                )
            )
        );
        // Get the daily count for the current day
        CounterComponent counterComponent = CounterComponent(
            _gameRegistry.getComponent(COUNTER_COMPONENT_ID)
        );
        uint256 dailyCount = counterComponent.getValue(currentDayWalletEntity);
        if (dailyCount >= entityList.length) {
            revert NotAvailable();
        }
        // Get the life purchase entity
        uint256 lifePurchaseEntity = entityList[dailyCount];
        LivesPurchaseComponentLayout
            memory lifePurchaseData = LivesPurchaseComponent(
                _gameRegistry.getComponent(LIVES_PURCHASE_COMPONENT_ID)
            ).getLayoutValue(lifePurchaseEntity);
        if (
            lifePurchaseData.livesAmount == 0 ||
            lifePurchaseData.lootEntity == 0
        ) {
            revert NotAvailable();
        }
        // Handle fee
        LootArrayComponentLibrary.burnV2Loot(
            LootArrayComponentLibrary.convertLootEntityArrayToLoot(
                _gameRegistry.getComponent(LOOT_ENTITY_ARRAY_COMPONENT_ID),
                lifePurchaseData.lootEntity
            ),
            account
        );
        // Increment the daily count
        counterComponent.setValue(currentDayWalletEntity, dailyCount + 1);
        uint256 currentLives = getLivesCount(account, livesType);
        // Make sure the new lives are not greater than the max lives
        if (
            currentLives + lifePurchaseData.livesAmount >
            _maxLives(account, livesType)
        ) {
            revert CannotExceedMaxLives();
        }
        // Grant the lives
        LivesComponent(_gameRegistry.getComponent(LIVES_COMPONENT_ID)).setValue(
                EntityLibrary.accountSubEntity(account, livesType),
                currentLives + lifePurchaseData.livesAmount,
                SafeCast.toUint32(block.timestamp)
            );
    }

    /** INTERNAL */

    /**
     * Internal function checks if the user has a pirate NFT and returns the max lives possible.
     */
    function _maxLives(
        address accountAddress,
        uint256 livesType
    ) internal view returns (uint256) {
        // If user owns zero Gen0 pirates and zero Gen1 pirates then revert
        if (
            IERC721(_getSystem(PIRATE_NFT_ID)).balanceOf(accountAddress) == 0 &&
            IERC721(_getSystem(STARTER_PIRATE_NFT_ID)).balanceOf(
                accountAddress
            ) ==
            0
        ) {
            revert NoPirateNFT();
        }
        uint256[] memory livesArray = Uint256ArrayComponent(
            _gameRegistry.getComponent(Uint256ArrayComponentId)
        ).getValue(livesType);
        // First value is the max lives for non-VIP and the second is the max lives for VIP
        if (livesArray.length == 0) {
            revert NotAvailable();
        }
        // VIP users get more lives
        if (
            ISubscriptionSystem(_gameRegistry.getSystem(SUBSCRIPTION_SYSTEM_ID))
                .checkHasActiveSubscription(
                    VIP_SUBSCRIPTION_TYPE,
                    accountAddress
                ) && livesArray.length > 1
        ) {
            return livesArray[1];
        }
        return livesArray[0];
    }
}
