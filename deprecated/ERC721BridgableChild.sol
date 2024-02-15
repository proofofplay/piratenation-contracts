// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "./IERC721BridgableChild.sol";

/// @notice This contract implements the Matic/Polygon bridging logic to allow tokens to be bridged back to mainnet
abstract contract ERC721BridgableChild is
    ERC721Enumerable,
    IERC721BridgableChild
{
    // Max batch size
    uint256 public constant BATCH_LIMIT = 20;

    /** EVENTS **/

    // Emitted when a token is deposited
    event DepositFromBridge(address indexed to, uint256 indexed tokenId);

    // @notice this event needs to be like this and unchanged so that the L1 can pick up the changes
    // @dev We don't use this event, everything is a single withdraw so metadata is always transferred
    // event WithdrawnBatch(address indexed user, uint256[] tokenIds);

    // @notice this event needs to be like this and unchanged so that the L1 can pick up the changes
    event TransferWithMetadata(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId,
        bytes metaData
    );

    /** ERRORS **/

    /// @notice Call was not made by owner
    error NotOwner();

    /// @notice Tried to withdraw too many tokens at once
    error ExceedsBatchLimit();

    /** EXTERNAL **/

    /**
     * @notice called when to wants to withdraw token back to root chain
     * @dev Should burn to's token. This transaction will be verified when exiting on root chain
     * @param tokenId tokenId to withdraw
     */
    function withdraw(uint256 tokenId) external {
        _withdrawWithMetadata(tokenId);
    }

    /**
     * @notice called when to wants to withdraw multiple tokens back to root chain
     * @dev Should burn to's tokens. This transaction will be verified when exiting on root chain
     * @param tokenIds tokenId list to withdraw
     */
    function withdrawBatch(uint256[] calldata tokenIds) external {
        uint256 length = tokenIds.length;
        if (length > BATCH_LIMIT) {
            revert ExceedsBatchLimit();
        }
        for (uint256 i; i < length; ++i) {
            uint256 tokenId = tokenIds[i];
            _withdrawWithMetadata(tokenId);
        }
    }

    /**
     * @notice called when to wants to withdraw token back to root chain with arbitrary metadata
     * @dev Should handle withraw by burning to's token.
     *
     * This transaction will be verified when exiting on root chain
     *
     * @param tokenId tokenId to withdraw
     */
    function withdrawWithMetadata(uint256 tokenId) external {
        _withdrawWithMetadata(tokenId);
    }

    /**
     * @notice This method is supposed to be called by client when withdrawing token with metadata
     * and pass return value of this function as second paramter of `withdrawWithMetadata` method
     *
     * It can be overridden by clients to encode data in a different form, which needs to
     * be decoded back by them correctly during exiting
     *
     * @param tokenId Token for which URI to be fetched
     */
    function encodeTokenMetadata(uint256 tokenId)
        external
        view
        virtual
        returns (bytes memory)
    {
        // You're always free to change this default implementation
        // and pack more data in byte array which can be decoded back
        // in L1
        return abi.encode(tokenURI(tokenId));
    }

    /** @return Whether or not the given tokenId has been minted/exists */
    function exists(uint256 tokenId) external view override returns (bool) {
        return _exists(tokenId);
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC721BridgableChild).interfaceId ||
            ERC721Enumerable.supportsInterface(interfaceId);
    }

    /** INTERNAL **/

    /// @dev executes the withdraw
    function _withdrawWithMetadata(uint256 tokenId) internal {
        if (_msgSender() != ownerOf(tokenId)) {
            revert NotOwner();
        }

        // Encoding metadata associated with tokenId & emitting event
        // This event needs to be exactly like this for the bridge to work
        emit TransferWithMetadata(
            _msgSender(),
            address(0),
            tokenId,
            this.encodeTokenMetadata(tokenId)
        );

        _burn(tokenId);
    }

    /**
     * @notice called when token is deposited on root chain
     * @dev Should be callable only by ChildChainManager
     * Should handle deposit by minting the required tokenId for to
     * Make sure minting is done only by this function
     * @param to address for whom deposit is being done
     * @param depositData abi encoded tokenId
     */
    function _deposit(address to, bytes calldata depositData) internal virtual {
        // deposit single
        if (depositData.length == 32) {
            uint256 tokenId = abi.decode(depositData, (uint256));
            _safeMint(to, tokenId);

            emit DepositFromBridge(to, tokenId);
        } else {
            // deposit batch
            uint256[] memory tokenIds = abi.decode(depositData, (uint256[]));
            uint256 length = tokenIds.length;
            for (uint256 i; i < length; ++i) {
                _safeMint(to, tokenIds[i]);
                emit DepositFromBridge(to, tokenIds[i]);
            }
        }
    }
}
