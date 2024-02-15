// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract ERC721EnumerableMock is ERC721Enumerable {
    // Override
    constructor(
        uint256 tokenMaxSupply,
        string memory name,
        string memory symbol,
        address gameRegistryAddress
    ) ERC721(name, symbol) {}

    function mintForTests(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }
}
