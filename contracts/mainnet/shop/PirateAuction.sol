/**
 *Submitted for verification at Etherscan.io on 2024-01-22
 */

// SPDX-License-Identifier: GPL-3.0

// LICENSE
// AuctionHouse.sol is a modified version of Zora's AuctionHouse.sol:
// https://github.com/ourzora/auction-house/blob/54a12ec1a6cf562e49f0a4917990474b11350a2d/contracts/AuctionHouse.sol
//
// AuctionHouse.sol source code Copyright Zora licensed under the GPL-3.0 license.
// With modifications by Nounders DAO.

pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ITokenShop} from "./PirateTokenShop.sol";

// Manager Role - Can adjust how contract functions (limits, paused, etc)
bytes32 constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

interface IPirateAuction {
    struct Auction {
        // The Shop SKU
        uint256 sku;
        // The current highest bid amount
        uint256 amount;
        // The time that the auction started
        uint256 startTime;
        // The time that the auction is scheduled to end
        uint256 endTime;
        // The address of the current highest bid
        address bidder;
        // Whether or not the auction has been settled
        bool settled;
        // Wether the bid is from stake or not.
        bool isFromStake;
    }

    event AuctionCreated(
        uint256 indexed sku,
        uint256 startTime,
        uint256 endTime
    );

    event AuctionBid(
        uint256 indexed sku,
        address sender,
        uint256 value,
        bool extended
    );

    event AuctionExtended(uint256 indexed sku, uint256 endTime);

    event AuctionSettled(uint256 indexed sku, address winner, uint256 amount);

    event AuctionTimeBufferUpdated(uint256 timeBuffer);

    event AuctionReservePriceUpdated(uint256 reservePrice);

    event AuctionMinBidIncrementPercentageUpdated(
        uint256 minBidIncrementPercentage
    );

    event AuctionDurationUpdated(uint256 duration);

    event AuctionTreasuryUpdated(address treasury);

    function settleAuction() external;

    function createBid(uint256 sku, uint256 amount) external;
}

contract PirateAuction is
    IPirateAuction,
    Initializable,
    PausableUpgradeable,
    ReentrancyGuard,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;

    address public allowedStakeContract;

    ITokenShop public shop;

    // The address of the Token
    IERC20 public token;

    // The minimum amount of time left in an auction after a new bid is created
    uint256 public timeBuffer;

    // The minimum price accepted in an auction
    uint256 public reservePrice;

    // The minimum percentage difference between the last bid amount and the current bid
    uint8 public minBidIncrementPercentage;

    // The duration of a single auction
    uint256 public duration;

    // Recipient of auction proceeds
    address public treasury;

    // The active auction
    IPirateAuction.Auction public auction;

    function initialize(
        address _token,
        address _allowedStakeContract,
        address _shop,
        address _treasury
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setRoleAdmin(MANAGER_ROLE, DEFAULT_ADMIN_ROLE);

        treasury = _treasury;
        allowedStakeContract = _allowedStakeContract;
        shop = ITokenShop(_shop);
        token = IERC20(_token);

        timeBuffer = 5 minutes;
        reservePrice = 1;
        minBidIncrementPercentage = 10;
        duration = 24 hours;
    }

    function configure(
        address _token,
        uint256 _timeBuffer,
        uint256 _reservePrice,
        uint8 _minBidIncrementPercentage,
        uint256 _duration
    ) external onlyRole(MANAGER_ROLE) {
        token = IERC20(_token);
        timeBuffer = _timeBuffer;
        reservePrice = _reservePrice;
        minBidIncrementPercentage = _minBidIncrementPercentage;
        duration = _duration;
    }

    /**
     * @notice Settle the current auction.
     */
    function settleAuction() external override whenNotPaused nonReentrant {
        _settleAuction();
    }

    /**
     * createBidWithPermit
     * @param sku The ID of the Sku to bid on
     */
    function createBidPermit(
        uint256 sku,
        uint256 amount,
        uint256 permitAmount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        IERC20Permit(address(token)).permit(
            _msgSender(),
            address(this),
            permitAmount,
            deadline,
            v,
            r,
            s
        );
        _createBid(sku, amount);
    }

    /**
     * @notice Create a bid for a token, with a given amount.
     * @dev You must have given approval for this contract.
     */
    function createBid(
        uint256 sku,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        _createBid(sku, amount);
    }

    function _createBid(uint256 sku, uint256 amount) internal {
        IPirateAuction.Auction memory _auction = auction;

        //todo: errors
        require(_auction.settled == false, "Auction already settled");
        require(_auction.sku == sku, "Sku not up for auction");
        require(block.timestamp < _auction.endTime, "Auction expired");
        require(amount >= reservePrice, "Must send at least reservePrice");
        require(
            amount >=
                _auction.amount +
                    ((_auction.amount * minBidIncrementPercentage) / 100),
            "Must send more than last bid by minBidIncrementPercentage amount"
        );

        address lastBidder = _auction.bidder;

        // Refund the last bidder, if applicable
        if (lastBidder != address(0)) {
            token.transfer(lastBidder, _auction.amount);
        }

        //todo: If the auction was from Stake, we need to tell the stake contract they deposited.
        // if (_auction.isFromStake) {
        //todo: Apply the purchase from Stake discount.
        // allowedStakeContract.depositFromFailedBid(
        //     auction.bidder,
        //     _auction.amount
        // );
        // }

        //transfer from the person to this.
        token.transferFrom(_msgSender(), address(this), msg.value);

        auction.amount = msg.value;
        auction.bidder = _msgSender();

        auction.isFromStake = msg.sender == allowedStakeContract;

        // Extend the auction if the bid was received within `timeBuffer` of the auction end time
        bool extended = _auction.endTime - block.timestamp < timeBuffer;
        if (extended) {
            auction.endTime = _auction.endTime = block.timestamp + timeBuffer;
        }

        emit AuctionBid(_auction.sku, _msgSender(), msg.value, extended);

        if (extended) {
            emit AuctionExtended(_auction.sku, _auction.endTime);
        }
    }

    /**
     * @notice Pause the auction house.
     * @dev This function can only be called by the owner when the
     * contract is unpaused. While no new auctions can be started when paused,
     * anyone can settle an ongoing auction.
     */
    function pause() external onlyRole(MANAGER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the auction house.
     * @dev This function can only be called by the owner when the
     * contract is paused. If required, this function will start a new auction.
     */
    function unpause() external onlyRole(MANAGER_ROLE) {
        _unpause();
    }

    /**
     * @notice Set the auction time buffer.
     * @dev Only callable by the owner.
     */
    function setTimeBuffer(
        uint256 _timeBuffer
    ) external onlyRole(MANAGER_ROLE) {
        timeBuffer = _timeBuffer;

        emit AuctionTimeBufferUpdated(_timeBuffer);
    }

    /**
     * @notice Set the auction reserve price.
     * @dev Only callable by the owner.
     */
    function setReservePrice(
        uint256 _reservePrice
    ) external onlyRole(MANAGER_ROLE) {
        reservePrice = _reservePrice;

        emit AuctionReservePriceUpdated(_reservePrice);
    }

    /**
     * @notice Set the auction minimum bid increment percentage.
     * @dev Only callable by the owner.
     */
    function setMinBidIncrementPercentage(
        uint8 _minBidIncrementPercentage
    ) external onlyRole(MANAGER_ROLE) {
        minBidIncrementPercentage = _minBidIncrementPercentage;

        emit AuctionMinBidIncrementPercentageUpdated(
            _minBidIncrementPercentage
        );
    }

    /**
     * @notice Set the auction duration.
     * @dev Only callable by the owner.
     */
    function setDuration(uint256 _duration) external onlyRole(MANAGER_ROLE) {
        duration = _duration;

        emit AuctionDurationUpdated(duration);
    }

    /**
     * @notice Set the treasury address.
     * @dev Only callable by the owner.
     */
    function setTreasury(address _treasury) external onlyRole(MANAGER_ROLE) {
        treasury = _treasury;

        emit AuctionTreasuryUpdated(treasury);
    }

    function createAuction(uint256 sku) external onlyRole(MANAGER_ROLE) {
        _createAuction(sku);
    }

    /**
     * @notice Create an auction.
     * @dev Store the auction details in the `auction` state variable and emit an AuctionCreated event.
     * If the mint reverts, the minter was updated without pausing this contract first. To remedy this,
     * catch the revert and pause this contract.
     */
    function _createAuction(uint256 sku) internal {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + duration;

        emit AuctionCreated(sku, startTime, endTime);
    }

    /**
     * @notice Settle an auction, finalizing the bid and paying out to the owner.
     * @dev If there are no bids, the token is sent to the treasury.
     */
    function _settleAuction() internal {
        IPirateAuction.Auction memory _auction = auction;

        require(_auction.startTime != 0, "Auction hasn't begun");
        require(!_auction.settled, "Auction has already been settled");
        require(
            block.timestamp >= _auction.endTime,
            "Auction hasn't completed"
        );

        auction.settled = true;

        if (_auction.bidder != address(0)) {
            //todo: Apply the purchase from Stake discount.
            shop.purchaseFromAuction(
                _auction.bidder,
                _auction.sku,
                _auction.amount
            );
        }

        if (_auction.amount > 0) {
            token.transfer(treasury, _auction.amount);
        }

        emit AuctionSettled(_auction.sku, _auction.bidder, _auction.amount);
    }
}
