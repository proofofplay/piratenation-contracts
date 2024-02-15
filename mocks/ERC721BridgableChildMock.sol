// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "../deprecated/ERC721BridgableChild.sol";

abstract contract ERC721BridgableChildMock is ERC721BridgableChild {
    bytes4 public IERC721BRIDGABLECHILD_INTERFACEID =
        type(IERC721BridgableChild).interfaceId;

    function depositForTests(address to, bytes calldata depositData) external {
        _deposit(to, depositData);
    }

    function mintForTests(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }
}
