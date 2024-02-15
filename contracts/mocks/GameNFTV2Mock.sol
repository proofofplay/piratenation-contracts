// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";

import "../tokens/gamenft/GameNFTV2.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.gamenftmock"));

/** @title GameNFTV2 Mock for testing */
contract GameNFTV2Mock is GameNFTV2 {
    using Strings for uint256;

    uint8 counter = 1;

    constructor(
        uint256 tokenMaxSupply,
        string memory name,
        string memory symbol,
        address gameRegistryAddress
    ) GameNFTV2(tokenMaxSupply, name, symbol, gameRegistryAddress, ID) {}

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
