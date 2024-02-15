// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

/** @title Global common constants for the game **/
library GameRegistryLibrary {
    /** Reservation constants -- Used to determined how a token was locked */
    uint32 internal constant RESERVATION_UNDEFINED = 0;
    uint32 internal constant RESERVATION_QUEST_SYSTEM = 1;
    uint32 internal constant RESERVATION_CRAFTING_SYSTEM = 2;

    /** Global generic structs that let the game contracts utilize/lock token resources */

    enum TokenType {
        UNDEFINED,
        ERC20,
        ERC721,
        ERC1155
    }

    // Generic Token Pointer
    struct TokenPointer {
        // Type of token
        TokenType tokenType;
        // Address of the token contract
        address tokenContract;
        // Id of the token (if ERC721 or ERC1155)
        uint256 tokenId;
        // Amount of the token (if ERC20 or ERC1155)
        uint256 amount;
    }

    // Reference to a GameItem
    struct GameItemPointer {
        // Address of the game item contract
        address tokenContract;
        // Id of the ERC1155 token
        uint256 tokenId;
        // Amount of ERC1155 that was staked
        uint256 amount;
    }

    // Reference to a GameNFT
    struct GameNFTPointer {
        // Address of the NFT contract
        address tokenContract;
        // Id of the NFT
        uint256 tokenId;
    }

    struct ReservedToken {
        // Type of token
        TokenType tokenType;
        // Address of the token contract
        address tokenContract;
        // Id of the token (if ERC721 or ERC1155)
        uint256 tokenId;
        // Amount of the token (if ERC20 or ERC1155)
        uint256 amount;
        // reservationId for the locking system
        uint32 reservationId;
    }

    // Struct to point and store game items
    struct ReservedGameItem {
        // Address of the game item contract
        address tokenContract;
        // Id of the ERC1155 token
        uint256 tokenId;
        // Amount of ERC1155 that was staked
        uint256 amount;
        // LockingSystem reservation id, puts a hold on the items
        uint32 reservationId;
    }

    // Struct to point and store game NFTs
    struct ReservedGameNFT {
        // Address of the NFT contract
        address tokenContract;
        // Id of the NFT
        uint256 tokenId;
        // LockingSystem reservationId to put a hold on the NFT
        uint32 reservationId;
    }
}
