// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;
import {ERC20Upgradeable, ContextUpgradeable, IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import {MINTER_ROLE, MANAGER_ROLE} from "../../Constants.sol";
import {IGoldToken, ID} from "./IGoldToken.sol";
import {GameRegistryConsumerUpgradeable} from "../../GameRegistryConsumerUpgradeable.sol";
import {IERC20BeforeTokenTransferHandler} from "@proofofplay/erc721-extensions/src/ERC20BeforeTokenTransferHandler.sol";

/** @title In-game Currency: Gold */
contract GoldToken is
    IGoldToken,
    GameRegistryConsumerUpgradeable,
    ERC20Upgradeable
{
    /// @notice Reference to the handler contract for transfer hooks
    address public beforeTokenTransferHandler;

    /** ERRORS **/

    /// @notice Invalid params
    error InvalidParams();

    /** SETUP */

    constructor() {
        // Do nothing
    }

    /**
     * Initializer function for upgradeable contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        GameRegistryConsumerUpgradeable.__GameRegistryConsumer_init(
            gameRegistryAddress,
            ID
        );
        ERC20Upgradeable.__ERC20_init("Pirate Gold", "PGLD");
    }

    /**
     * Sets the after token transfer handler
     *
     * @param handlerAddress  Address to the transfer hook handler contract
     */
    function setBeforeTokenTransferHandler(
        address handlerAddress
    ) external onlyRole(MANAGER_ROLE) {
        beforeTokenTransferHandler = handlerAddress;
    }

    /**
     * Mint token to recipient
     *
     * @param to      The recipient of the token
     * @param amount  The amount of token to mint
     */
    function mint(
        address to,
        uint256 amount
    ) external override whenNotPaused onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @dev No restriction for paused
     * Batch mint token to recipients
     *
     * @param toAddresses  The recipients of the token
     * @param amounts      The amounts of token to mint
     */
    function batchMint(
        address[] calldata toAddresses,
        uint256[] calldata amounts
    ) external whenNotPaused onlyRole(MINTER_ROLE) {
        if (toAddresses.length != amounts.length) {
            revert InvalidParams();
        }
        for (uint256 i = 0; i < toAddresses.length; i++) {
            _mint(toAddresses[i], amounts[i]);
        }
    }

    /**
     * Burn token from holder
     *
     * @param from    The holder of the token
     * @param amount  The amount of token to burn
     */
    function burn(
        address from,
        uint256 amount
    ) external override whenNotPaused onlyRole(MINTER_ROLE) {
        _burn(from, amount);
    }

    /**
     * @inheritdoc ERC20Upgradeable
     * @dev Note: minters can also move currency around to allow in-game actions.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    )
        public
        virtual
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (bool)
    {
        // Minters can move currency around to enable gameplay
        if (_hasAccessRole(MINTER_ROLE, _msgSender())) {
            // Note this avoids events
            _transfer(sender, recipient, amount);
            return true;
        }

        // Normal ERC20 security flow (need approval, etc.)
        return super.transferFrom(sender, recipient, amount);
    }

    /** INTERNAL */

    /**
     * Message sender override to get Context to work with meta transactions
     *
     */
    function _msgSender()
        internal
        view
        override(ContextUpgradeable, GameRegistryConsumerUpgradeable)
        returns (address)
    {
        return GameRegistryConsumerUpgradeable._msgSender();
    }

    /**
     * Message data override to get Context to work with meta transactions
     *
     */
    function _msgData()
        internal
        view
        override(ContextUpgradeable, GameRegistryConsumerUpgradeable)
        returns (bytes calldata)
    {
        return GameRegistryConsumerUpgradeable._msgData();
    }

    /**
     * @notice Handles any before-transfer actions
     * @inheritdoc ERC20Upgradeable
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (beforeTokenTransferHandler != address(0)) {
            IERC20BeforeTokenTransferHandler handlerRef = IERC20BeforeTokenTransferHandler(
                    beforeTokenTransferHandler
                );

            handlerRef.beforeTokenTransfer(
                address(this),
                _msgSender(),
                from,
                to,
                amount
            );
        }

        super._beforeTokenTransfer(from, to, amount);
    }
}
