// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {IGameItems, ID as GAME_ITEMS_CONTRACT_ID} from "../tokens/gameitems/IGameItems.sol";
import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {ISubscriptionSystem, ID} from "./ISubscriptionSystem.sol";
import {SubscriptionGrantedConfigComponent, Layout as SubscriptionGrantedConfigComponentLayout, ID as SUBSCRIPTION_GRANTED_CONFIG_COMPONENT_ID} from "../generated/components/SubscriptionGrantedConfigComponent.sol";
import {ExpiresAtComponent, Layout as ExpiresAtComponentLayout, ID as EXPIRES_AT_COMPONENT_ID} from "../generated/components/ExpiresAtComponent.sol";

/**
 * @title SubscriptionSystem
 * @notice Handles granting new subscriptions or extending existing ones
 */
contract SubscriptionSystem is
    GameRegistryConsumerUpgradeable,
    ISubscriptionSystem
{
    /** ERRORS */

    /// @notice Missing Ticket config data
    error MissingTicketConfigData();

    /// @notice Missing Ticket in wallet
    error MissingTicket();

    /// @notice Invalid Game Item ticket
    error InvalidGameItemTicket();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /** GETTERS */

    /**
     * @dev Check if an account has an active subscription
     * @param subscriptionType Type of subscription to check
     * @param account Address of the account to check
     */
    function checkHasActiveSubscription(
        uint256 subscriptionType,
        address account
    ) public view override returns (bool) {
        uint256 accountSubEntity = EntityLibrary.accountSubEntity(
            account,
            subscriptionType
        );
        // Get players current subscription expiration time for the given subscription type
        uint32 expiresAt = ExpiresAtComponent(
            _gameRegistry.getComponent(EXPIRES_AT_COMPONENT_ID)
        ).getValue(accountSubEntity);
        // Check if player has an active subscription
        return expiresAt >= block.timestamp;
    }

    /** EXTERNAL */

    /**
     * @dev User triggered function to burn a Ticket game item and be granted a new subscription or extend the current active one
     */
    function consumeTicket(
        uint256 gameItemEntity
    ) public nonReentrant whenNotPaused {
        // Get user account
        address account = _getPlayerAccount(_msgSender());
        (address tokenContract, uint256 ticketGameItemsId) = EntityLibrary
            .entityToToken(gameItemEntity);
        // Check if player has a Ticket game item in their wallet
        IGameItems gameItems = IGameItems(
            _gameRegistry.getSystem(GAME_ITEMS_CONTRACT_ID)
        );
        if (tokenContract != address(gameItems)) {
            revert InvalidGameItemTicket();
        }
        SubscriptionGrantedConfigComponentLayout
            memory subConfig = SubscriptionGrantedConfigComponent(
                _gameRegistry.getComponent(
                    SUBSCRIPTION_GRANTED_CONFIG_COMPONENT_ID
                )
            ).getLayoutValue(gameItemEntity);
        if (subConfig.subscriptionType == 0 || subConfig.timeToGrant == 0) {
            revert MissingTicketConfigData();
        }
        if (gameItems.balanceOf(account, ticketGameItemsId) == 0) {
            revert MissingTicket();
        }
        // Burn 1 Ticket game item
        gameItems.burn(account, ticketGameItemsId, 1);
        // Grant the player a subscription or extend the current one
        _grantSubscription(
            subConfig.subscriptionType,
            subConfig.timeToGrant,
            account
        );
    }

    /**
     * @dev Get the expiration time of a subscription
     * @param subscriptionType Type of subscription to check
     * @param account Address of the account to check
     */
    function getSubscriptionExpirationTime(
        uint256 subscriptionType,
        address account
    ) public view override returns (uint32) {
        uint256 accountSubEntity = EntityLibrary.accountSubEntity(
            account,
            subscriptionType
        );
        return
            ExpiresAtComponent(
                _gameRegistry.getComponent(EXPIRES_AT_COMPONENT_ID)
            ).getValue(accountSubEntity);
    }

    /** INTERNAL */

    /**
     * @dev Grant a subscription to an account
     * @param subscriptionType Type of subscription to grant
     * @param timeToGrant Time to grant the subscription for
     * @param account Address of the account to grant a subscription to
     */
    function _grantSubscription(
        uint256 subscriptionType,
        uint32 timeToGrant,
        address account
    ) internal {
        // Get players current subscription time
        ExpiresAtComponent subExpiresComponent = ExpiresAtComponent(
            _gameRegistry.getComponent(EXPIRES_AT_COMPONENT_ID)
        );
        uint256 accountSubEntity = EntityLibrary.accountSubEntity(
            account,
            subscriptionType
        );
        uint32 expiresAt = subExpiresComponent.getValue(accountSubEntity);

        uint32 newExpirationTime;
        // If player has an active subscription, extend it
        if (expiresAt >= block.timestamp) {
            newExpirationTime = uint32(expiresAt + timeToGrant);
        } else {
            newExpirationTime = uint32(block.timestamp + timeToGrant);
        }
        expiresAt = newExpirationTime;
        subExpiresComponent.setValue(accountSubEntity, expiresAt);
    }
}
