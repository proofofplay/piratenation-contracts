// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "../tokens/PirateNFTL2.sol";
import {IGameNFTV2} from "../tokens/gamenft/IGameNFTV2.sol";

/** @title PirateNFTL2 Mock for testing */
contract PirateNFTL2Mock is PirateNFTL2 {
    using Strings for uint256;

    bytes4 public GAMENFT_INTERFACEID = type(IGameNFTV2).interfaceId;
    bytes4 public ITRAITSCONSUMER_INTERFACEID =
        type(ITraitsConsumer).interfaceId;

    constructor(address gameRegistryAddress) PirateNFTL2(gameRegistryAddress) {}

    function mintForTests(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }

    function burnForTests(uint256 tokenId) external {
        _burn(tokenId);
    }

    function mintWithoutTraits(address to, uint256 tokenId) external {
        ERC721._safeMint(to, tokenId);
    }
}
