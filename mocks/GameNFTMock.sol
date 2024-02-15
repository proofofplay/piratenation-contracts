// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";

import "../deprecated/GameNFT.sol";
import {ID as PIRATE_NFT_ID} from "../tokens/PirateNFTL2.sol";

/** @title Game NFT Mock for testing */
contract GameNFTMock is GameNFT {
    using Strings for uint256;

    uint8 counter = 1;

    constructor(
        uint256 tokenMaxSupply,
        string memory name,
        string memory symbol,
        address gameRegistryAddress
    )
        GameNFT(
            tokenMaxSupply,
            name,
            symbol,
            gameRegistryAddress,
            PIRATE_NFT_ID
        )
    {}

    function depositForTests(address to, bytes calldata depositData) external {
        _deposit(to, depositData);
    }

    function burnForTests(uint256 tokenId) external {
        _burn(tokenId);
    }

    function mintForTests(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
        counter = uint8(tokenId + 1);
    }

    function mintWithoutTraits(address to, uint256 tokenId) external {
        ERC721._safeMint(to, tokenId);
    }

    function mintBatch(address to, uint8 amount) external {
        for (uint8 i; i < amount; ++i) {
            _safeMint(to, counter);
            counter += 1;
        }
    }
}
