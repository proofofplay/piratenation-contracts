// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import {IERC165, ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MANAGER_ROLE} from "../Constants.sol";
import {GUIDLibrary} from "../core/GUIDLibrary.sol";
import {TimeRangeLibrary} from "../core/TimeRangeLibrary.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {EnabledComponent, ID as ENABLED_COMPONENT_ID} from "../generated/components/EnabledComponent.sol";
import {ID as LOOT_ARRAY_COMPONENT_ID} from "../generated/components/LootArrayComponent.sol";
import {MintCounterComponent, Layout as MintCounterLayout, ID as MINT_COUNTER_COMPONENT_ID} from "../generated/components/MintCounterComponent.sol";
import {ShopFixedPricingComponent, Layout as ShopFixedPricingLayout, ID as SHOP_FIXED_PRICING_COMPONENT_ID} from "../generated/components/ShopFixedPricingComponent.sol";
import {ShopListingComponent, Layout as ShopListingLayout, ID as SHOP_LISTING_COMPONENT_ID} from "../generated/components/ShopListingComponent.sol";
import {ShopReceiptComponent, Layout as ShopReceiptLayout, ID as SHOP_RECEIPT_COMPONENT_ID} from "../generated/components/ShopReceiptComponent.sol";
import {TimeRangeComponent, Layout as TimeRangeComponentLayout, ID as TIME_RANGE_COMPONENT_ID} from "../generated/components/TimeRangeComponent.sol";
import {ILootSystem} from "../loot/ILootSystem.sol";
import {LootArrayComponentLibrary} from "../loot/LootArrayComponentLibrary.sol";

// Partner Minter Role - Can mint items, NFTs, and ERC20 currency from Shop
bytes32 constant SHOP_MINTER_ROLE = keccak256("SHOP_MINTER_ROLE");

uint256 constant ID = uint256(keccak256("game.piratenation.shoplistingsystem"));

contract ShopListingSystem is ERC165, GameRegistryConsumerUpgradeable {
    struct Components {
        MintCounterLayout counter;
        ShopListingLayout listing;
        ShopFixedPricingLayout pricing;
    }

    // Errors

    /// @notice Minting quantity must not exceed listing limity
    error InvalidQuantity(uint32 quantity, uint32 limit);

    /// @notice Listing must have all required values set
    error InvalidListing(uint256 price, uint32 supply);

    /// @notice SKU must have required componment data set
    error InvalidSKU(string message);

    /// @notice Listing must be enabled and within its time range
    error InactiveListing(bool isEnabled, bool isActive);

    /// @notice Payment amount must match listing price
    error InsufficientFundsSent(uint256 amount, uint256 price);

    /// @notice Listing must have enough supply
    error ListingOutOfStock(uint256 mints, uint32 supply);

    /// @notice Contract must have a valid treasury address
    error MissingAddressConfig(
        address treasuryAddress,
        address paymentTokenAddress
    );

    // USDC token address used by Crossmint
    address public _paymentTokenAddress;

    // PoP shop treasury address
    address public _treasuryAddress;

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function setPaymentTokenAddress(
        address paymentTokenAddress
    ) external onlyRole(MANAGER_ROLE) {
        _paymentTokenAddress = paymentTokenAddress;
    }

    function setTreasuryAddress(
        address treasuryAddress
    ) external onlyRole(MANAGER_ROLE) {
        _treasuryAddress = treasuryAddress;
    }

    /**
     * Withdraws USDC funds from Crossmint treasury and mints SKU for a Shop listing
     * @dev Must have USDC allowance for Crossmint treasury and listing must have `price`
     * @param to Address that shop listing loot will be minted to
     * @param skuEntity Entity of the SKU to mint
     * @param quantity Amount of SKU's to mint
     */
    function processOrder(
        address to,
        uint256 skuEntity,
        uint8 quantity
    ) external nonReentrant onlyRole(SHOP_MINTER_ROLE) whenNotPaused {
        Components memory components = _getComponents(skuEntity);
        uint256 price = components.pricing.price;

        // Validate listing
        _validateOrder(components, price, skuEntity, quantity);

        // Transfer the ERC20 to this contract
        // NOTE: USDC is a 6 decimal token: 1_000_000 → 1 USDC
        // NOTE: must transfer from msg.sender, NOT the _to address
        IERC20(_paymentTokenAddress).transferFrom(
            msg.sender,
            _treasuryAddress,
            price * quantity
        );

        // Mint SKU to address and record purchase with receipt
        _fulfillOrder(components.counter, to, skuEntity, quantity);
        _generateReceipt(price * quantity, 0, skuEntity, quantity, to);
    }

    /**
     * Accepts native on-chain payment and mints SKU for a Shop listing
     * @dev Must send ETH with the transaction, and listing must have `ethPrice`
     * @param to Address that shop listing loot will be minted to
     * @param skuEntity Entity of the SKU to mint
     * @param quantity Amount of SKU's to mint
     */
    function processEthOrder(
        address to,
        uint256 skuEntity,
        uint8 quantity
    ) external payable nonReentrant onlyRole(SHOP_MINTER_ROLE) whenNotPaused {
        // TODO: FINISH WRITING TEST CASES FOR THIS FUNCTION
        require(false, "Not implemented");

        Components memory components = _getComponents(skuEntity);
        uint256 price = components.pricing.ethPrice;
        uint256 totalPrice = price * quantity;

        // Validate listing
        _validateOrder(components, price, skuEntity, quantity);
        if (msg.value != totalPrice) {
            revert InsufficientFundsSent(msg.value, totalPrice);
        }

        // Mint SKU to address and record purchase with receipt
        _fulfillOrder(components.counter, to, skuEntity, quantity);
        _generateReceipt(0, totalPrice, skuEntity, quantity, to);

        // Transfer funds to Shop treasury account
        (bool s, ) = payable(_treasuryAddress).call{value: totalPrice}("");
        require(s, "Failed to send funds to treasury");
    }

    /**
     * Fulfills a valid order, minting loot to the purchaser's address
     * @param to Address that shop listing loot will be minted to
     * @param skuEntity Entity of the SKU to mint
     * @param quantity Amount of SKU's to mint
     */
    function _fulfillOrder(
        MintCounterLayout memory counter,
        address to,
        uint256 skuEntity,
        uint8 quantity
    ) internal returns (ILootSystem.Loot[] memory loots) {
        // Mint SKU to address, check for valid loots
        loots = LootArrayComponentLibrary.convertLootArrayToLootSystem(
            _gameRegistry.getComponent(LOOT_ARRAY_COMPONENT_ID),
            skuEntity
        );
        if (loots.length == 0) {
            revert InvalidSKU("SKU loot array component not set");
        }

        // Batch grant loot; reverts if VRF is set to loots
        ILootSystem lootSystem = _lootSystem();
        lootSystem.batchGrantLootWithoutRandomness(to, loots, quantity);

        // Update minted count
        counter.mints += quantity;
        MintCounterComponent(
            _gameRegistry.getComponent(MINT_COUNTER_COMPONENT_ID)
        ).setLayoutValue(skuEntity, counter);
    }

    function _generateReceipt(
        uint256 subtotal,
        uint256 ethSubtotal,
        uint256 skuEntity,
        uint8 quantity,
        address account
    ) internal {
        // Generate receipt
        uint256 receiptEntity = GUIDLibrary.guid(
            _gameRegistry,
            "shoplistingsystem.receipt"
        );

        uint256[] memory skuEntities = new uint256[](1);
        skuEntities[0] = skuEntity;

        uint8[] memory quantities = new uint8[](1);
        quantities[0] = quantity;

        // Create a receipt entry
        ShopReceiptComponent(
            _gameRegistry.getComponent(SHOP_RECEIPT_COMPONENT_ID)
        ).setLayoutValue(
                receiptEntity,
                ShopReceiptLayout({
                    subtotal: subtotal,
                    ethSubtotal: ethSubtotal,
                    purchaseTime: block.timestamp,
                    skuEntities: skuEntities,
                    quantities: quantities,
                    account: account
                })
            );
    }

    function _getComponents(
        uint256 skuEntity
    ) internal view returns (Components memory components) {
        components.counter = MintCounterComponent(
            _gameRegistry.getComponent(MINT_COUNTER_COMPONENT_ID)
        ).getLayoutValue(skuEntity);
        components.listing = ShopListingComponent(
            _gameRegistry.getComponent(SHOP_LISTING_COMPONENT_ID)
        ).getLayoutValue(skuEntity);
        components.pricing = ShopFixedPricingComponent(
            _gameRegistry.getComponent(SHOP_FIXED_PRICING_COMPONENT_ID)
        ).getLayoutValue(skuEntity);
    }

    function _validateOrder(
        Components memory components,
        uint256 listingPrice,
        uint256 skuEntity,
        uint32 quantity
    ) internal view {
        bool isEnabled = EnabledComponent(
            _gameRegistry.getComponent(ENABLED_COMPONENT_ID)
        ).getValue(skuEntity);

        bool isActive = TimeRangeLibrary.checkWithinOptionalTimeRange(
            _gameRegistry.getComponent(TIME_RANGE_COMPONENT_ID),
            skuEntity
        );

        // Validate listing
        if (
            listingPrice == 0 ||
            (components.listing.hasUnlimitedSupply == false &&
                components.listing.supply == 0)
        ) {
            // Listing must have a price and a supply configured
            revert InvalidListing(listingPrice, components.listing.supply);
        } else if (isEnabled == false || isActive == false) {
            // SKU must be enabled and within its time range
            revert InactiveListing(isEnabled, isActive);
        } else if (
            components.listing.hasUnlimitedSupply == false &&
            components.counter.mints + quantity > components.listing.supply
        ) {
            // Listing must have enough quantity
            revert ListingOutOfStock(
                components.counter.mints + quantity,
                components.listing.supply
            );
        }

        // Validate order params
        if (quantity > components.listing.purchaseLimit) {
            revert InvalidQuantity(quantity, components.listing.purchaseLimit);
        }

        // Validate contract
        if (
            _treasuryAddress == address(0) || _paymentTokenAddress == address(0)
        ) {
            revert MissingAddressConfig(_treasuryAddress, _paymentTokenAddress);
        }
    }
}
