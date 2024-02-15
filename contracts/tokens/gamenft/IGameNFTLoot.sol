// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

interface IGameNFTLoot {
    /**
     * Mints a specific token
     *
     * @param to         Account to mint to
     * @param tokenId    Id of token to mint
     */
    function mint(address to, uint256 tokenId) external;

    /**
     * Mint multiple NFT's, meant to be used by the loot system
     *
     * @param to        Address to mint to
     * @param amount    Number of NFTs to mint
     */
    function mintBatch(address to, uint8 amount) external;
}
