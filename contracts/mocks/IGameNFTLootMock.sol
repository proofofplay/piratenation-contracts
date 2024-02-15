// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../tokens/gamenft/IGameNFTLoot.sol";
import "../GameRegistryConsumer.sol";
import {MINTER_ROLE} from "../Constants.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.igamenftlootmock"));

/** @title Pirate NFT Mock for testing */
contract IGameNFTLootMock is GameRegistryConsumer, IGameNFTLoot, ERC721 {
    uint256 _id = 0;

    constructor(address gameRegistryAddress)
        ERC721("Generic Loot", "GLT")
        GameRegistryConsumer(gameRegistryAddress, ID)
    {
        // Do nothing
    }

    /**
     * Mint token to recipient
     *
     * @param to      The recipient of the token
     * @param tokenId  The amount of token to mint
     */
    function mint(address to, uint256 tokenId)
        external
        override
        onlyRole(MINTER_ROLE)
    {
        _safeMint(to, tokenId);
    }

    /**
     * Mint multiple NFT's, meant to be used by the loot system
     *
     * @param to        Address to mint to
     * @param amount    Number of NFTs to mint
     */
    function mintBatch(address to, uint8 amount)
        external
        onlyRole(MINTER_ROLE)
    {
        for (uint8 i; i < amount; ++i) {
            _safeMint(to, _id);
            _id += 1;
        }
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
