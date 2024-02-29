// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

interface IERC1155BeforeTokenTransferHandler {
    /**
     * Before transfer hook for GameItems. Performs any trait checks needed before transfer
     *
     * @param tokenContract     Address of the token contract
     * @param operator          Operator address*
     * @param from              From address
     * @param to                To address
     * @param ids               Ids to transfer
     * @param amounts           Amounts to transfer
     * @param data              Additional data for transfer
     */
    function beforeTokenTransfer(
        address tokenContract,
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;
}
