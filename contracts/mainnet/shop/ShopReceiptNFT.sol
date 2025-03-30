// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");

/**
 * @title ShopReceiptNFT
 * @dev A contract for minting NFTs as receipts for shop purchases.
 */
contract ShopReceiptNFT is
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    AccessControlUpgradeable
{
    string public baseURI;

    function initialize() public initializer {
        __ERC721_init("Pirate Nation Receipt", "PNRECEIPT");
        __ERC721URIStorage_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Set the base URI for the tokenURI function
     * @param newURI The new base URI
     */
    function setBaseURI(
        string calldata newURI
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = newURI;
    }

    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev The base URI for the tokenURI function
     */
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    /**
     * @dev Override _transfer to prevent transfers except by authorized operations
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        require(
            from == address(0) || // Minting
            to == address(0),     // Burning
            "ShopReceiptNFT: token transfer is disabled"
        );
        super._transfer(from, to, tokenId);
    }

    /**
     * @dev Mint a new token
     * @param to The address to mint the token to
     * @param purchaseId The purchase ID to mint a receipt for.
     */
    function mint(address to, uint256 purchaseId) public onlyRole(MINTER_ROLE) {
        _mint(to, purchaseId);
    }

    // The following functions are overrides required by Solidity.

    function _burn(
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
