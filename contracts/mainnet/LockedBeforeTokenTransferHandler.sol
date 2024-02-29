// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "./IBeforeTokenTransferHandler.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * A before transfer hook that blocks all transfer except for the owners address.
 * Used for deploying new contracts, or times we need to do migrations.
 */
contract LockedBeforeTokenTransferHandler is IBeforeTokenTransferHandler, Ownable {
    /** ERRORS **/
    error Unauthorized();


    /**
     * Handles before token transfer events from a ERC721 contract.
     */
    function beforeTokenTransfer(
        address tokenContract,
        address operator,
        address from,
        address to,
        uint256 tokenId
    ) external view {
        beforeTokenTransfer(tokenContract, operator, from, to, tokenId, 1);
    }

    /**
     * Handles before token transfer events from a ERC721 contract.
     */
    function beforeTokenTransfer(
        address,
        address,
        address,
        address,
        uint256,
        uint256
    ) public view {
        if (tx.origin != owner()) {
            revert Unauthorized();
        }
    }
}
