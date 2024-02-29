// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

interface IERC721BeforeTokenTransferHandler {
    /**
     * Before transfer hook for NFTs. Performs any trait checks needed before transfer
     *
     * @param tokenContract     Address of the token contract
     * @param tokenId           Id of the token to generate traits for
     * @param from              From address
     * @param to                To address
     * @param operator          Operator address
     */
    function beforeTokenTransfer(
        address tokenContract,
        address operator,
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) external;
}
