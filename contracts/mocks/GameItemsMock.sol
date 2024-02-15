// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "../tokens/gameitems/GameItems.sol";

/** @title Game Items Mock for testing */
contract GameItemsMock is GameItems {
    bytes4 public ITRAITSCONSUMER_INTERFACEID =
        type(ITraitsConsumer).interfaceId;

    constructor(address gameRegistryAddress) GameItems(gameRegistryAddress) {}

    // Minting for test environemnts
    function mintForTests(uint32 tokenId, uint256 amount) external {
        _safeMint(_msgSender(), tokenId, amount);
    }
}
