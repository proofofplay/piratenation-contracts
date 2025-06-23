// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.26;

import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";

import {EntityLibrary} from "../core/EntityLibrary.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import {GameItems, ID as GAME_ITEMS_ID} from "../tokens/gameitems/GameItems.sol";
import {ShipNFT, ID as SHIP_NFT_ID} from "../tokens/shipnft/ShipNFT.sol";

import {MarketplaceListingStaticDataComponent, Layout as MarketplaceListingStaticDataComponentLayout, ID as MARKETPLACE_LISTING_STATIC_DATA_COMPONENT_ID} from "../generated/components/MarketplaceListingStaticDataComponent.sol";
import {MarketplaceListingDynamicDataComponent, Layout as MarketplaceListingDynamicDataComponentLayout, ID as MARKETPLACE_LISTING_DYNAMIC_DATA_COMPONENT_ID} from "../generated/components/MarketplaceListingDynamicDataComponent.sol";
import {MarketplaceOrderComponent, Layout as MarketplaceOrderComponentLayout, ID as MARKETPLACE_ORDER_COMPONENT_ID} from "../generated/components/MarketplaceOrderComponent.sol";

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

    /// @notice Invalid listing data
    error InvalidListingData();

    /// @notice Invalid order data
    error InvalidOrderData();

    /// @notice Invalid NFT type
    error InvalidNftType();

    /// @notice Invalid GameItem entity
    error InvalidGameItemEntity();

    /// @notice Listing is not active
    error ListingNotActive();

    /// @notice Listing already cancelled
    error ListingAlreadyCancelled();

    /// @notice Insufficient quantity
    error InsufficientQuantity();

    /** STRUCTS **/

    /// @notice Struct Data for createListing input
    struct MarketplaceListingData {
        uint256 listingId;
        uint256[] assetIds;
        uint256[] quantities;
        address maker;
    }

    /// @notice Struct Data for fulfillOrder input
    struct MarketplaceOrderData {
        uint256 orderId;
        uint256 listingId;
        uint256[] assetIds;
        uint256[] quantities;
        address taker;
    }

    /** ENUMS **/

    /// @notice Enum for listing status
    enum ListingStatus {
        UNDEFINED,
        ACTIVE,
        FILLED,
        CANCELLED
    }

    /** EVENTS **/

    /// @notice Event emitted when a listing is created
    event ListingCreated(
        uint256 indexed listingId,
        uint256[] assetIds,
        address indexed maker,
        uint256[] quantities
    );

    /// @notice Event emitted when an order is fulfilled
    event OrderFulfilled(
        uint256 indexed orderId,
        uint256 indexed listingId,
        address indexed taker,
        uint256[] assetIds,
        uint256[] quantities
    );

    /// @notice Event emitted when a listing is cancelled
    event ListingCancelled(uint256 indexed listingId);

    /// @notice Event emitted when a listing is completed
    event ListingFilled(uint256 indexed listingId);

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
     * @notice Creates a marketplace listing
     * @param listingData The data for the listing
     */
    function createListing(
        MarketplaceListingData memory listingData
    ) external whenNotPaused nonReentrant onlyRole(MARKETPLACE_ADMIN_ROLE) {
        if (
            listingData.listingId == 0 ||
            listingData.assetIds.length == 0 ||
            listingData.quantities.length == 0 ||
            listingData.maker == address(0)
        ) {
            revert InvalidListingData();
        }
        // Handle ERC721s later
        for (uint256 i = 0; i < listingData.assetIds.length; i++) {
            (address tokenAddress, uint256 tokenId) = EntityLibrary
                .entityToToken(listingData.assetIds[i]);
            if (tokenAddress != _gameRegistry.getSystem(GAME_ITEMS_ID)) {
                revert InvalidGameItemEntity();
            }
            // Burn the GameItems
            GameItems(tokenAddress).burn(
                listingData.maker,
                tokenId,
                listingData.quantities[i]
            );
        }
        // Set the listing static data
        MarketplaceListingStaticDataComponent(
            _gameRegistry.getComponent(
                MARKETPLACE_LISTING_STATIC_DATA_COMPONENT_ID
            )
        ).setLayoutValue(
                listingData.listingId,
                MarketplaceListingStaticDataComponentLayout({
                    listingId: listingData.listingId,
                    listingEntities: listingData.assetIds,
                    quantities: listingData.quantities,
                    listingTimestamp: uint32(block.timestamp),
                    maker: listingData.maker
                })
            );
        // Set the listing dynamic data
        MarketplaceListingDynamicDataComponent(
            _gameRegistry.getComponent(
                MARKETPLACE_LISTING_DYNAMIC_DATA_COMPONENT_ID
            )
        ).setLayoutValue(
                listingData.listingId,
                MarketplaceListingDynamicDataComponentLayout({
                    listingStatus: uint32(ListingStatus.ACTIVE),
                    quantitiesRemaining: listingData.quantities
                })
            );

        emit ListingCreated(
            listingData.listingId,
            listingData.assetIds,
            listingData.maker,
            listingData.quantities
        );
    }

    /**
     * @notice Fulfills an order
     * @param orderData The data for the order
     */
    function fulfillOrder(
        MarketplaceOrderData memory orderData
    ) external whenNotPaused nonReentrant onlyRole(MARKETPLACE_ADMIN_ROLE) {
        if (
            orderData.orderId == 0 ||
            orderData.listingId == 0 ||
            orderData.quantities.length == 0 ||
            orderData.taker == address(0)
        ) {
            revert InvalidOrderData();
        }
        MarketplaceListingDynamicDataComponent listingDynamicDataComponent = MarketplaceListingDynamicDataComponent(
                _gameRegistry.getComponent(
                    MARKETPLACE_LISTING_DYNAMIC_DATA_COMPONENT_ID
                )
            );
        MarketplaceListingDynamicDataComponentLayout
            memory listingDynamicData = listingDynamicDataComponent
                .getLayoutValue(orderData.listingId);
        // Check if the listing is active
        if (listingDynamicData.listingStatus != uint32(ListingStatus.ACTIVE)) {
            revert ListingNotActive();
        }
        for (uint256 i = 0; i < orderData.assetIds.length; i++) {
            // Check if the listing has enough quantity remaining
            if (
                listingDynamicData.quantitiesRemaining[i] <
                orderData.quantities[i]
            ) {
                revert InsufficientQuantity();
            }
            // Handle ERC721s later

            (address tokenAddress, uint256 tokenId) = EntityLibrary
                .entityToToken(orderData.assetIds[i]);
            if (tokenAddress != _gameRegistry.getSystem(GAME_ITEMS_ID)) {
                revert InvalidGameItemEntity();
            }
            // Mint the GameItems
            GameItems(tokenAddress).mint(
                orderData.taker,
                tokenId,
                orderData.quantities[i]
            );
        }
        // Set the order primary data
        MarketplaceOrderComponent(
            _gameRegistry.getComponent(MARKETPLACE_ORDER_COMPONENT_ID)
        ).setLayoutValue(
                orderData.orderId,
                MarketplaceOrderComponentLayout({
                    listingId: orderData.listingId,
                    assetIds: orderData.assetIds,
                    quantitiesFilled: orderData.quantities,
                    orderTimestamp: uint32(block.timestamp),
                    taker: orderData.taker
                })
            );
        // Update the listing secondary non-static data
        for (uint256 i = 0; i < orderData.assetIds.length; i++) {
            listingDynamicData.quantitiesRemaining[i] -= orderData.quantities[
                i
            ];
        }
        // Check if the listing is filled
        bool isFilled = true;
        for (
            uint256 i = 0;
            i < listingDynamicData.quantitiesRemaining.length;
            i++
        ) {
            if (listingDynamicData.quantitiesRemaining[i] > 0) {
                isFilled = false;
                break;
            }
        }
        emit OrderFulfilled(
            orderData.orderId,
            orderData.listingId,
            orderData.taker,
            orderData.assetIds,
            orderData.quantities
        );
        if (isFilled) {
            listingDynamicData.listingStatus = uint32(ListingStatus.FILLED);
            emit ListingFilled(orderData.listingId);
        }
        listingDynamicDataComponent.setLayoutValue(
            orderData.listingId,
            listingDynamicData
        );
    }

    /**
     * @notice Cancels a listing
     * @param listingId The ID of the listing to cancel
     */
    function cancelListing(
        uint256 listingId
    ) external whenNotPaused nonReentrant onlyRole(MARKETPLACE_ADMIN_ROLE) {
        MarketplaceListingDynamicDataComponent listingDynamicDataComponent = MarketplaceListingDynamicDataComponent(
                _gameRegistry.getComponent(
                    MARKETPLACE_LISTING_DYNAMIC_DATA_COMPONENT_ID
                )
            );
        MarketplaceListingDynamicDataComponentLayout
            memory listingDynamicData = listingDynamicDataComponent
                .getLayoutValue(listingId);
        if (
            listingDynamicData.listingStatus == uint32(ListingStatus.CANCELLED)
        ) {
            revert ListingAlreadyCancelled();
        }
        if (listingDynamicData.listingStatus != uint32(ListingStatus.ACTIVE)) {
            revert ListingNotActive();
        }
        listingDynamicData.listingStatus = uint32(ListingStatus.CANCELLED);
        listingDynamicDataComponent.setLayoutValue(
            listingId,
            listingDynamicData
        );
        emit ListingCancelled(listingId);
    }
}
