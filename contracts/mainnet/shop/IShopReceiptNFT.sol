// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

interface IShopReceiptNFT is IERC721, IERC721Metadata {
    function mint(address to, uint256 purchaseId) external;
}
