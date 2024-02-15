// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../IERC721BridgableChild.sol";
import "../mainnet/IERC721BridgableParent.sol";

/** @title Mock bridge for testing bridging flows locally */
contract PolygonBridgeMock is Ownable {
    /// @notice Map parent to child token address
    mapping(address => address) public parentToChildMapping;

    /// @notice Map child to parent token address
    mapping(address => address) public childToParentMapping;

    /// @notice Parent locked tokens
    mapping(address => mapping(uint256 => bool)) public parentLockedTokens;

    constructor() {}

    /// @notice Maps a parent chain address to child chain address
    function mapToken(address parentAddress, address childAddress)
        external
        onlyOwner
    {
        require(
            parentToChildMapping[parentAddress] == address(0) &&
                childToParentMapping[childAddress] == address(0),
            "TOKEN_ALREADY_MAPPED: Either parent or child is already mapped"
        );
        parentToChildMapping[parentAddress] = childAddress;
        childToParentMapping[childAddress] = parentAddress;
    }

    /// @notice Deposit from parent contract to child contract
    function deposit(address parentAddress, uint256 tokenId) external {
        require(
            parentToChildMapping[parentAddress] != address(0),
            "TOKEN_NOT_MAPPED: Token has not been mapped"
        );

        // Lock on parent
        IERC721 parentContract = IERC721(parentAddress);
        parentContract.transferFrom(_msgSender(), address(this), tokenId);
        parentLockedTokens[parentAddress][tokenId] = true;

        // Mint on child (L2)
        IERC721BridgableChild childContract = IERC721BridgableChild(
            parentToChildMapping[parentAddress]
        );
        childContract.deposit(_msgSender(), abi.encode(tokenId));
    }

    // Withdraws from child contract to parent contract
    function withdrawWithMetadata(
        address childAddress,
        uint256 tokenId,
        bytes calldata metadata
    ) external {
        address parentAddress = childToParentMapping[childAddress];
        require(
            parentAddress != address(0),
            "TOKEN_NOT_MAPPED: Token has not been mapped"
        );

        // Verify token was locked
        require(
            parentLockedTokens[parentAddress][tokenId] == true,
            "TOKEN_NOT_DEPOSITED: No token was previously deposited"
        );

        // Verify token was burned
        IERC721BridgableChild childContract = IERC721BridgableChild(
            childAddress
        );
        require(
            childContract.exists(tokenId) == false,
            "TOKEN_NOT_BURNED: Token needs to be burned before withdraw"
        );

        // Lock on parent
        IERC721BridgableParent parentContract = IERC721BridgableParent(
            parentAddress
        );
        parentContract.transferFrom(address(this), _msgSender(), tokenId);
        parentContract.setTokenMetadata(tokenId, metadata);
        parentLockedTokens[parentAddress][tokenId] = false;
    }
}
