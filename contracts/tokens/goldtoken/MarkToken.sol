// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IGoldToken} from "./IGoldToken.sol";
import {MINTER_ROLE} from "../../Constants.sol";
import {GameRegistryConsumer} from "../../GameRegistryConsumer.sol";
import {ERC20BeforeTokenTransferHandler} from "@proofofplay/erc721-extensions/src/ERC20BeforeTokenTransferHandler.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.marktoken"));

/**
 * @title A Mark Token is a token that cannot be traded. Used for lowbies
 * @author Proof of Play
 */
contract MarkToken is
    IGoldToken,
    GameRegistryConsumer,
    ERC20BeforeTokenTransferHandler
{
    /** ERRORS **/

    /// @notice Invalid params
    error InvalidParams();

    constructor(
        address gameRegistryAddress
    )
        ERC20("Pirate Marks", "MARK")
        GameRegistryConsumer(gameRegistryAddress, ID)
    {
        // Do nothing
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
     * @inheritdoc ERC20
     * @dev Note: minters can also move currency around to allow in-game actions.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    )
        public
        virtual
        override(ERC20, IERC20)
        onlyRole(MINTER_ROLE)
        returns (bool)
    {
        _transfer(sender, recipient, amount);
        return true;
    }

    /**
     * Message sender override to get Context to work with meta transactions
     *
     */
    function _msgSender()
        internal
        view
        override(Context, GameRegistryConsumer)
        returns (address)
    {
        return GameRegistryConsumer._msgSender();
    }

    /**
     * Message data override to get Context to work with meta transactions
     *
     */
    function _msgData()
        internal
        view
        override(Context, GameRegistryConsumer)
        returns (bytes calldata)
    {
        return GameRegistryConsumer._msgData();
    }
}
