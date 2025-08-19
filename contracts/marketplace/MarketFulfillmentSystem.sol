// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.26;

import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";

import {EntityLibrary} from "../core/EntityLibrary.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import {GameItems, ID as GAME_ITEMS_ID} from "../tokens/gameitems/GameItems.sol";
import {ShipNFT, ID as SHIP_NFT_ID} from "../tokens/shipnft/ShipNFT.sol";

import {ListingEscrowedReplayComponent, Layout as ListingEscrowedReplayComponentLayout, ID as LISTING_ESCROWED_REPLAY_COMPONENT_ID} from "../generated/components/ListingEscrowedReplayComponent.sol";
import {OrderFulfilledReplayComponent, Layout as OrderFulfilledReplayComponentLayout, ID as ORDER_FULFILLED_REPLAY_COMPONENT_ID} from "../generated/components/OrderFulfilledReplayComponent.sol";
import {ListingCancelledReplayComponent, Layout as ListingCancelledReplayComponentLayout, ID as LISTING_CANCELLED_REPLAY_COMPONENT_ID} from "../generated/components/ListingCancelledReplayComponent.sol";

// ID of this contract
uint256 constant ID = uint256(
    keccak256("game.piratenation.marketfulfillmentsystem")
);

// Marketplace Admin Role - Can cancel listings and fulfill orders
bytes32 constant MARKETPLACE_ADMIN_ROLE = keccak256("MARKETPLACE_ADMIN_ROLE");

/**
 * @title MarketFulfillmentSystem
 */
contract MarketFulfillmentSystem is GameRegistryConsumerUpgradeable {
    /** ERRORS **/

    /// @notice Invalid order data
    error InvalidOrderData();

    /// @notice Order already fulfilled
    error OrderAlreadyFulfilled();

    /// @notice Listing already escrowed
    error ListingAlreadyEscrowed();

    /// @notice Listing already cancelled
    error ListingAlreadyCancelled();

    /** STRUCTS **/

    /// @notice Struct Data for fulfillOrder input
    struct FulfillOrderData {
        uint256 orderId;
        uint256[] assetIds;
        uint256[] quantities;
        address user;
    }

    /// @notice Struct Data for escrowListing input
    struct ListingEscrowData {
        uint256 listingId;
        uint256[] assetIds;
        uint256[] quantities;
        address user;
    }

    /// @notice Struct Data for cancelListing input
    struct CancelListingData {
        uint256 listingId;
        uint256[] assetIds;
        uint256[] quantities;
        address user;
    }

    /** EVENTS **/

    /// @notice Event emitted when an order is escrowed aka listing created
    event ListingEscrowed(
        uint256 indexed listingId,
        address indexed user,
        uint256[] assetIds,
        uint256[] quantities
    );

    /// @notice Event emitted when an order is fulfilled aka listing filled
    event OrderFulfilled(
        uint256 indexed orderId,
        address indexed user,
        uint256[] assetIds,
        uint256[] quantities
    );

    /// @notice Event emitted when a listing is cancelled
    event ListingCancelled(uint256 indexed listingId);

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
     * @notice Fulfills an order, this is the equivalent of a listing being filled
     * This mints the game items to the user for the order
     * @param orderData The data for the order
     */
    function fulfillOrder(
        FulfillOrderData memory orderData
    ) external whenNotPaused nonReentrant onlyRole(MARKETPLACE_ADMIN_ROLE) {
        if (
            orderData.orderId == 0 ||
            orderData.assetIds.length == 0 ||
            orderData.quantities.length == 0 ||
            orderData.assetIds.length != orderData.quantities.length ||
            orderData.user == address(0)
        ) {
            revert InvalidOrderData();
        }
        // Replay protection
        OrderFulfilledReplayComponent orderFulfilledReplayComponent = OrderFulfilledReplayComponent(
                _gameRegistry.getComponent(ORDER_FULFILLED_REPLAY_COMPONENT_ID)
            );
        if (
            orderFulfilledReplayComponent
                .getLayoutValue(orderData.orderId)
                .value != 0
        ) {
            revert OrderAlreadyFulfilled();
        }
        orderFulfilledReplayComponent.setLayoutValue(
            orderData.orderId,
            OrderFulfilledReplayComponentLayout({
                value: uint256(block.timestamp)
            })
        );
        GameItems gameItems = GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID));
        // Handle ERC721s later
        for (uint256 i = 0; i < orderData.assetIds.length; i++) {
            (, uint256 tokenId) = EntityLibrary.entityToToken(
                orderData.assetIds[i]
            );
            // Mint the GameItems
            gameItems.mint(orderData.user, tokenId, orderData.quantities[i]);
        }

        emit OrderFulfilled(
            orderData.orderId,
            orderData.user,
            orderData.assetIds,
            orderData.quantities
        );
    }

    /**
     * @notice Escrows a listing, this is the equivalent of a listing being created
     * This burns the game items from the user for the listing
     * @param orderData The data for the order
     */
    function escrowListing(
        ListingEscrowData memory orderData
    ) external whenNotPaused nonReentrant onlyRole(MARKETPLACE_ADMIN_ROLE) {
        if (
            orderData.listingId == 0 ||
            orderData.assetIds.length == 0 ||
            orderData.quantities.length == 0 ||
            orderData.assetIds.length != orderData.quantities.length ||
            orderData.user == address(0)
        ) {
            revert InvalidOrderData();
        }
        // Replay protection
        ListingEscrowedReplayComponent listingEscrowedReplayComponent = ListingEscrowedReplayComponent(
                _gameRegistry.getComponent(LISTING_ESCROWED_REPLAY_COMPONENT_ID)
            );
        if (
            listingEscrowedReplayComponent
                .getLayoutValue(orderData.listingId)
                .value != 0
        ) {
            revert ListingAlreadyEscrowed();
        }
        listingEscrowedReplayComponent.setLayoutValue(
            orderData.listingId,
            ListingEscrowedReplayComponentLayout({
                value: uint256(block.timestamp)
            })
        );
        GameItems gameItems = GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID));
        // Handle ERC721s later
        for (uint256 i = 0; i < orderData.assetIds.length; i++) {
            (, uint256 tokenId) = EntityLibrary.entityToToken(
                orderData.assetIds[i]
            );
            // Burn the GameItems
            gameItems.burn(orderData.user, tokenId, orderData.quantities[i]);
        }
        emit ListingEscrowed(
            orderData.listingId,
            orderData.user,
            orderData.assetIds,
            orderData.quantities
        );
    }

    /**
     * @notice Cancels a listing
     * This mints the game items to the user back to the user for the listing
     * @param orderData The data for the order
     */
    function cancelListing(
        CancelListingData memory orderData
    ) external whenNotPaused nonReentrant onlyRole(MARKETPLACE_ADMIN_ROLE) {
        // Replay protection
        ListingCancelledReplayComponent listingCancelledReplayComponent = ListingCancelledReplayComponent(
                _gameRegistry.getComponent(
                    LISTING_CANCELLED_REPLAY_COMPONENT_ID
                )
            );
        if (
            listingCancelledReplayComponent
                .getLayoutValue(orderData.listingId)
                .value != 0
        ) {
            revert ListingAlreadyCancelled();
        }
        listingCancelledReplayComponent.setLayoutValue(
            orderData.listingId,
            ListingCancelledReplayComponentLayout({
                value: uint256(block.timestamp)
            })
        );
        GameItems gameItems = GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID));
        // Handle ERC721s later
        for (uint256 i = 0; i < orderData.assetIds.length; i++) {
            (, uint256 tokenId) = EntityLibrary.entityToToken(
                orderData.assetIds[i]
            );
            // Mint the GameItems
            gameItems.mint(orderData.user, tokenId, orderData.quantities[i]);
        }
        emit ListingCancelled(orderData.listingId);
    }
}
