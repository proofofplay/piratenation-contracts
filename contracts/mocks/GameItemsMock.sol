// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "../tokens/gameitems/GameItems.sol";

/** @title Game Items Mock for testing */
contract GameItemsMock is GameItems {
    // Minting for test environemnts
    function mintForTests(uint32 tokenId, uint256 amount) external {
        address to = _gameRegistry.getPlayerAccount(_msgSender());
        _safeMint(to, tokenId, amount);
    }
}
