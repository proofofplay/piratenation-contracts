// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IGameItems, ID as GAME_ITEMS_CONTRACT_ID} from "./IGameItems.sol";
import {MINTER_ROLE} from "../../Constants.sol";
import {GameRegistryConsumerUpgradeable} from "../../GameRegistryConsumerUpgradeable.sol";
import {IGameItemsHelper, ID} from "./IGameItemsHelper.sol";

/**
 * @title GameItemsHelper
 */
contract GameItemsHelper is GameRegistryConsumerUpgradeable {
    /** ERRORS */

    /// @notice Invalid length of addresses, ids, or amounts
    error ImproperLength();

    /// @notice Invalid zero value for address, id, or amount
    error InvalidZeroValue(uint256 index);

    /// @notice Invalid input
    error ImproperInput();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /** EXTERNAL */

    /**
     * @dev Trigger a batch mint of game items to a list of addresses with a list of ids and amounts
     */
    function batchMint(
        address[] calldata addresses,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) public nonReentrant whenNotPaused onlyRole(MINTER_ROLE) {
        if (
            addresses.length != ids.length || addresses.length != amounts.length
        ) {
            revert ImproperLength();
        }
        IGameItems gameItems = IGameItems(
            _gameRegistry.getSystem(GAME_ITEMS_CONTRACT_ID)
        );
        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] == address(0) || ids[i] == 0 || amounts[i] == 0) {
                revert InvalidZeroValue(i);
            }
            gameItems.mint(addresses[i], ids[i], amounts[i]);
        }
    }

    /**
     * Trigger a batch mint of game items to a list of addresses with a single id and amount
     */
    function batchAddressMint(
        address[] calldata addresses,
        uint256 id,
        uint256 amount
    ) public nonReentrant whenNotPaused onlyRole(MINTER_ROLE) {
        if (addresses.length == 0 || id == 0 || amount == 0) {
            revert ImproperInput();
        }
        IGameItems gameItems = IGameItems(
            _gameRegistry.getSystem(GAME_ITEMS_CONTRACT_ID)
        );
        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] == address(0)) {
                revert InvalidZeroValue(i);
            }
            gameItems.mint(addresses[i], id, amount);
        }
    }
}
