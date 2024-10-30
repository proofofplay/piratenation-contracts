// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

//todo: should we upgrade OZ for this to be trasient? MV think yes.
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Listings Role - Can Set Pricing, Quantity of SKUs
bytes32 constant LISTINGS_ROLE = keccak256("LISTINGS_ROLE");

// Price Index Role - Can adjust the manual index price.
bytes32 constant PRICE_INDEX_ROLE = keccak256("PRICE_INDEX_ROLE");

// Manager Role - Can adjust how contract functions (limits, paused, etc)
bytes32 constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

/**
 * @title ITokenShop
 * @dev Interface for the Purchase contract outlining PurchaseFromStake
 */
interface ITokenShop {
    function purchaseFromStake(
        address purchaser,
        uint256[] calldata skuEntities,
        uint256[] calldata quantities
    ) external returns (uint256 purchaseId, uint256 total);

    // function purchaseFromAuction(
    //     address purchaser,
    //     uint256 sku,
    //     uint256 amount
    // ) external returns (uint256 purchaseId, uint256 total);
}

// @notice Emitted when purchasing from stake and an invalid Stake Contract is set
error InvalidStakeContract();

// @notice Emitted when the inputs are invalid
error InvalidInputs();

// @notice Emitted when the item is sold out
error ItemSoldOut();

// @notice Emitted when the max items are exceeded
error MaxItemsExceeded();

// @notice Emitted when the skus are not in order - this is required to prevent people from avoiding the MaxItemsLimit.
error SkusMustBeInOrder();

// @notice Emitted when is not purchaseable because Auction
error MustBePurchasedByAuction();

// @notice Stake-only purchase
error MustBePurchasedByStake();

// @notice Max Purchases Exceeded
error MaxPurchasesExceeded();

/**
 * The Pirate Token shop is a contract that allows users to purchase items using an ERC20 token.
 */
contract PirateTokenShop is
    ITokenShop,
    Initializable,
    ContextUpgradeable,
    ReentrancyGuard,
    AccessControlUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    // @notice The ERC20 token used to purchase items
    IERC20 public token;

    // @notice The address of the funds reciever
    address public fundsReciever;

    // @notice The address of the allowed stake contract
    address public allowedStakeContract;

    // @notice The amount out of 100 (for percent discount) for purchaes made from Staking Contract
    uint256 public stakingDiscount;

    // @notice PurchaseId is an incrementing number for each purchase used to identify purchases
    uint256 public purchaseId;

    // @notice The limit of one sku type that can be purchased in a single transaction
    uint256 public itemsLimit = 10;

    // @notice The manual price index - used to quickly adjust all prices in the system.
    uint256 public priceIndex = 100;

    // @notice The SKU struct represents a purchasable item in the shop
    struct Sku {
        // @notice The price of the SKU in the Tokens Curency
        uint256 price;
        // @notice The quantity of the SKU available for purchase
        uint32 quantity;
        // @notice If the SKU is unlimited, it can be purchased as many times as desired
        bool unlimited;
        // @notice If the SKU is a stake-only purchase
        bool stakeOnly;
        // @notice Max purchases per wallet allowed for this SKU
        uint32 maxPurchaseByAccount;
    }

    // @notice The mapping of SKU entities to their Sku struct
    mapping(uint256 => Sku) public skus;

    // @notice If the SKU is an auction or not.
    mapping(uint256 => bool) public auctionable;

    // @notice the address of the public auction contract
    address public auctionContract;

    // @notice The mapping of user addresses to sku id to their purchase count
    mapping(address => mapping(uint256 => uint256))
        public userToSkuIdToPurchaseCount;

    // @notice Emitted when a purchase is made
    event Purchase(
        address indexed purchaser,
        uint256 indexed purchaseId,
        uint256[] skuEntities,
        uint256[] quantities,
        uint256 amount,
        uint256 discount
    );

    /**
     * @notice Initialize the contract with the ERC20 token and the claim contract
     * @param _token The address of the ERC20 token
     * @param _allowedStakeContract The address of staking contract allowed to make purchases
     */
    function initialize(
        address _token,
        address _allowedStakeContract
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();
        token = IERC20(_token);
        allowedStakeContract = address(_allowedStakeContract);

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setRoleAdmin(LISTINGS_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(PRICE_INDEX_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(MANAGER_ROLE, DEFAULT_ADMIN_ROLE);

        _pause();
    }

    /**
     * @dev Update the address of the token contract
     * @param _token The address of the ERC20 token
     */
    function updateTokenContract(
        address _token
    ) external onlyRole(MANAGER_ROLE) {
        token = IERC20(_token);
    }

    /**
     * @dev Update the address of the allowed stake contract
     * @param _allowedStakeContract The address of the staking contract
     */
    function updateAllowedStakeContract(
        address _allowedStakeContract
    ) external onlyRole(MANAGER_ROLE) {
        allowedStakeContract = _allowedStakeContract;
    }

    /**
     * @dev Update the auction contract address
     * @param _auctionContract the address of the auction contract
     */
    function updateAuctionContract(
        address _auctionContract
    ) external onlyRole(MANAGER_ROLE) {
        auctionContract = _auctionContract;
    }

    /**
     * @dev Withdraw the tokens from the contract
     * @param amount The amount of tokens to withdraw
     * @notice The funds reciever is the address that receives the funds from the purchases
     */
    function withdraw(uint256 amount) external onlyRole(MANAGER_ROLE) {
        if (fundsReciever == address(0)) {
            revert InvalidInputs();
        }

        token.transfer(fundsReciever, amount);
    }

    /**
     * @dev Set the SKUs in the shop
     * @param skuEntities The array of SKU entities
     * @param skuValues The array of Sku values
     */
    function setSkus(
        uint256[] calldata skuEntities,
        Sku[] calldata skuValues
    ) external onlyRole(LISTINGS_ROLE) {
        if (skuEntities.length != skuValues.length) {
            revert InvalidInputs();
        }

        for (uint256 i = 0; i < skuEntities.length; i++) {
            skus[skuEntities[i]] = skuValues[i];
            //auctionable[skuEntities[i]] = isAuction[i];
        }
    }

    /**
     * @dev Set the price index
     * @param _priceIndex The price index
     * @notice The price index is used to adjust all prices in the system
     */
    function setPriceIndex(
        uint256 _priceIndex
    ) external onlyRole(PRICE_INDEX_ROLE) {
        priceIndex = _priceIndex;
    }

    /**
     * @dev Set the items limit
     * @param _itemsLimit The limit of one sku type that can be purchased in a single transaction
     * @notice The items limit is used to prevent users from purchasing too many items in a single transaction
     */
    function setItemsLimit(
        uint256 _itemsLimit
    ) external onlyRole(MANAGER_ROLE) {
        itemsLimit = _itemsLimit;
    }

    /**
     * @dev Set the funds reciever
     * @param _fundsReciever The address of the funds reciever
     * @notice The funds reciever is the address that receives the funds from the purchases
     */
    function setFundsReciever(
        address _fundsReciever
    ) external onlyRole(MANAGER_ROLE) {
        fundsReciever = _fundsReciever;
    }

    /**
     * @dev Set the staking discount
     * @param _stakingDiscount The amount out of 100 (for percent discount) for purchaes made from Staking Contract
     * @notice The staking discount is used to apply a discount to purchases made from the staking contract
     */
    function setStakingDiscount(
        uint256 _stakingDiscount
    ) external onlyRole(MANAGER_ROLE) {
        if (_stakingDiscount > 100) {
            revert InvalidInputs();
        }
        stakingDiscount = _stakingDiscount;
    }

    /**
     * @dev Pause or unpause the contract
     * @param paused The boolean to pause or unpause the contract
     * @notice The contract can be paused to prevent purchases
     */
    function setPaused(bool paused) external onlyRole(MANAGER_ROLE) {
        if (paused) {
            _pause();
        } else {
            _unpause();
        }
    }

    /**
     * @dev Purchase from the stake contract
     * @param purchaser The address of the purchaser
     * @param skuEntities The array of SKU entities
     * @param quantities The array of quantities for each SKU
     * @return purchaseId The purchase ID
     * @return total The total amount of the purchase
     * @notice This function is called by the stake contract to make a purchase
     */
    function purchaseFromStake(
        address purchaser,
        uint256[] calldata skuEntities,
        uint256[] calldata quantities
    ) external override whenNotPaused returns (uint256, uint256) {
        if (allowedStakeContract != msg.sender) {
            revert InvalidStakeContract();
        }

        return
            _purchase(
                purchaser,
                skuEntities,
                quantities,
                stakingDiscount,
                true
            );
    }

    /**
     * @dev Purchase from the shop
     * @param skuEntities The array of SKU entities - the Sku Entities must be provided in incrementing order
     * @param quantities The array of quantities for each SKU
     * @return purchaseId The purchase ID
     * @return total The total amount of the purchase
     * @notice This function is called by the user to make a purchase
     * @notice The user must approve the contract to transfer the tokens
     * @notice The tokens are transferred to the contract and then to the funds reciever
     * @notice The purchase is successful if the user has enough tokens and the SKU is available
     * @notice The purchase ID is an incrementing number for each purchase used to identify purchases
     */
    function purchase(
        uint256[] calldata skuEntities,
        uint256[] calldata quantities
    ) external whenNotPaused returns (uint256, uint256) {
        return _purchase(_msgSender(), skuEntities, quantities, 0, false);
    }

    /**
     * @dev Purchase from the shop with a permit
     * @param skuEntities The array of SKU entities - the Sku Entities must be provided in incrementing order
     * @param quantities The array of quantities for each SKU
     * @param amount The amount of tokens to transfer
     * @param deadline The deadline for the permit
     * @param v The v value of the permit signature
     * @param r The r value of the permit signature
     * @param s The s value of the permit signature
     * @return purchaseId The purchase ID
     * @return total The total amount of the purchase
     * @notice This function is called by the user to make a purchase with a permit
     * @notice The permit is used to approve the contract to transfer the tokens
     * @notice The tokens are transferred to the contract and then to the funds reciever
     * @notice The purchase is successful if the user has enough tokens and the SKU is available
     * @notice The purchase ID is an incrementing number for each purchase used to identify purchases
     */
    function purchasePermit(
        uint256[] calldata skuEntities,
        uint256[] calldata quantities,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external whenNotPaused returns (uint256, uint256) {
        IERC20Permit(address(token)).permit(
            _msgSender(),
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );

        return _purchase(_msgSender(), skuEntities, quantities, 0, false);
    }

    // internal
    function _purchase(
        address purchaser,
        uint256[] calldata skuEntities,
        uint256[] calldata quantities,
        uint256 discount,
        bool stakeOnlyPurchase
    ) internal returns (uint256, uint256) {
        if (
            skuEntities.length == 0 || skuEntities.length != quantities.length
        ) {
            revert InvalidInputs();
        }

        uint256 total = 0;
        purchaseId++;

        for (uint256 i = 0; i < skuEntities.length; i++) {
            if (i > 0 && skuEntities[i] <= skuEntities[i - 1]) {
                revert SkusMustBeInOrder();
            }
            if (quantities[i] == 0) {
                revert InvalidInputs();
            }

            // if (auctionable[skuEntities[i]]) {
            //     revert MustBePurchasedByAuction();
            // }

            Sku storage sku = skus[skuEntities[i]];
            // Enforce stakeOnly purchases
            if (sku.stakeOnly == true && stakeOnlyPurchase == false) {
                revert MustBePurchasedByStake();
            }
            // If listing is marked as unlimited, we can purchase as many as we want
            // Otherwise, we need to check if we have enough quantity to purchase
            if (!sku.unlimited) {
                if (quantities[i] > sku.quantity) {
                    revert ItemSoldOut();
                }
                if (quantities[i] > itemsLimit) {
                    revert MaxItemsExceeded();
                }
                // Reduce quantity of Sku
                sku.quantity = sku.quantity - uint32(quantities[i]);
                // Enforce max purchases per wallet allowed and increment purchase count
                if (
                    userToSkuIdToPurchaseCount[purchaser][skuEntities[i]] +
                        quantities[i] >
                    sku.maxPurchaseByAccount
                ) {
                    revert MaxPurchasesExceeded();
                }
                userToSkuIdToPurchaseCount[purchaser][
                    skuEntities[i]
                ] += quantities[i];
            }
            total += sku.price * quantities[i];
        }

        //apply price index
        total = (total * priceIndex) / 100;

        //apply discount
        if (discount > 0 && discount <= 100) {
            total = (total * (100 - discount)) / 100;
        }

        // Transfer directly from the caller to this contract
        token.transferFrom(msg.sender, address(this), total);

        // Purchase is successful! Emit event for Oracle to pick up deliver on client chain
        // And helpful for accounting
        emit Purchase(
            purchaser,
            purchaseId,
            skuEntities,
            quantities,
            total,
            discount
        );

        return (purchaseId, total);
    }

    /**
     * The auctioneer can make purchases
     *
     * @param purchaser the address of the auction winner
     * @param sku the sku that will be delivered
     * @param amount the amount they won the auction for
     */
    // function purchaseFromAuction(
    //     address purchaser,
    //     uint256 sku,
    //     uint256 amount
    // ) public returns (uint256, uint256) {
    //     if (msg.sender != auctionContract) {
    //         revert MustBePurchasedByAuction();
    //     }

    //     purchaseId++;

    //     uint256[] memory skuEntities = new uint256[](1);
    //     skuEntities[0] = sku;

    //     uint256[] memory quantities = new uint256[](1);
    //     quantities[0] = 1;

    //     emit Purchase(
    //         purchaser,
    //         purchaseId,
    //         skuEntities,
    //         quantities,
    //         amount,
    //         0
    //     );

    //     return (purchaseId, amount);
    // }
}
