// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "../../mainnet/PirateNFTParent.sol";

/** @title Pirate NFT Mock for testing */
contract PirateNFTParentMock is PirateNFTParent {
    bytes4 public IERC721BRIDGABLEPARENT_INTERFACEID =
        type(IERC721BridgableParent).interfaceId;

    constructor(uint256 maxSupply) PirateNFTParent(maxSupply) {}

    function mintForTests(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }
}
