// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "../tokens/shipnft/ShipNFT.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";

/** @title Ship NFT Mock for testing */
contract ShipNFTMock is ShipNFT {
    using Strings for uint256;

    bytes4 public GAMENFT_INTERFACEID = type(IGameNFT).interfaceId;
    bytes4 public ITRAITSCONSUMER_INTERFACEID =
        type(ITraitsConsumer).interfaceId;
    bytes4 public IERC721BRIDGABLECHILD_INTERFACEID =
        type(IERC721BridgableChild).interfaceId;

    constructor(address gameRegistryAddress) ShipNFT(gameRegistryAddress) {}

    function depositForTests(address to, bytes calldata depositData) external {
        _deposit(to, depositData);
    }

    function burnForTests(uint256 tokenId) external {
        _burn(tokenId);
    }

    function mintForTests(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }

    function mintWithoutTraits(address to, uint256 tokenId) external {
        ERC721._safeMint(to, tokenId);
    }

    function getEntity(uint256 tokenId) external view returns (uint256) {
        return EntityLibrary.tokenToEntity(address(this), tokenId);
    }
}
