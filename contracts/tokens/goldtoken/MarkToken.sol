// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import {ERC20Upgradeable, ContextUpgradeable, IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import {MINTER_ROLE, MANAGER_ROLE} from "../../Constants.sol";
import {IGoldToken} from "./IGoldToken.sol";
import {GameRegistryConsumerUpgradeable} from "../../GameRegistryConsumerUpgradeable.sol";
import {IERC20BeforeTokenTransferHandler} from "@proofofplay/erc721-extensions/src/ERC20BeforeTokenTransferHandler.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.marktoken"));

/**
 * @title A Mark Token is a token that cannot be traded. Used for lowbies
 * @author Proof of Play
 */
contract MarkToken is
    IGoldToken,
    GameRegistryConsumerUpgradeable,
    ERC20Upgradeable
{
    /// @notice Reference to the handler contract for transfer hooks
    address public beforeTokenTransferHandler;

    /** ERRORS **/

    /// @notice Invalid params
    error InvalidParams();

    /**
     * Initializer function for upgradeable contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        GameRegistryConsumerUpgradeable.__GameRegistryConsumer_init(
            gameRegistryAddress,
            ID
        );
        ERC20Upgradeable.__ERC20_init("Pirate Marks", "MARK");
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

    function transfer(
        address recipient,
        uint256 amount
    ) public virtual override(ERC20Upgradeable, IERC20Upgradeable) onlyRole(MINTER_ROLE) returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
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
        onlyRole(MINTER_ROLE)
        returns (bool)
    {
        _transfer(sender, recipient, amount);
        return true;
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
