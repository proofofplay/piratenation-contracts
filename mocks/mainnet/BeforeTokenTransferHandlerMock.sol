// SPDX-License-Identifier: MIT LICENSE

import "../../mainnet/IBeforeTokenTransferHandler.sol";

pragma solidity ^0.8.9;

contract BeforeTokenTransferHandlerMock is IBeforeTokenTransferHandler {
    // Test error
    error CannotTransfer(address operator);

    /**
     * Handles before token transfer events from a ERC721 contract
     */
    function beforeTokenTransfer(
        address,
        address operator,
        address,
        address,
        uint256
    ) external pure {
        // Always fail
        revert CannotTransfer(operator);
    }

    /**
     * Handles before token transfer events from a ERC721 contract
     */
    function beforeTokenTransfer(
        address,
        address operator,
        address,
        address,
        uint256,
        uint256
    ) external pure {
        // Always fail
        revert CannotTransfer(operator);
    }
}
