// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {IERC721BeforeTokenTransferHandler} from "./IERC721BeforeTokenTransferHandler.sol";

import {MANAGER_ROLE} from "../../Constants.sol";

abstract contract ERC721OperatorFilterUpgradeable is
    ContextUpgradeable,
    ERC721Upgradeable
{
    /// @notice Reference to the handler contract for transfer hooks
    address public beforeTokenTransferHandler;

    /**
     * Sets the before token transfer handler
     *
     * @param handlerAddress  Address to the transfer hook handler contract
     */
    function setBeforeTokenTransferHandler(address handlerAddress) external {
        _checkRole(MANAGER_ROLE, _msgSender());
        beforeTokenTransferHandler = handlerAddress;
    }

    /**
     * @notice Handles any pre-transfer actions
     * @inheritdoc ERC721Upgradeable
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal virtual override {
        if (beforeTokenTransferHandler != address(0)) {
            IERC721BeforeTokenTransferHandler handlerRef = IERC721BeforeTokenTransferHandler(
                    beforeTokenTransferHandler
                );
            handlerRef.beforeTokenTransfer(
                address(this),
                _msgSender(),
                from,
                to,
                tokenId,
                batchSize
            );
        }

        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    /**
     * This will be included by GameRegistryConsumer which checks the gameRegistry for various roles
     * @param role The role to check
     * @param account The account to check
     */
    function _checkRole(bytes32 role, address account) internal virtual;

    uint256[49] private __gap;
}
