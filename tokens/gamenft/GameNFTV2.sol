// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IGameNFTV2} from "./IGameNFTV2.sol";
import {MANAGER_ROLE} from "../../Constants.sol";

import {ITraitsProvider} from "../../interfaces/ITraitsProvider.sol";

import {ITraitsConsumer, TraitsConsumer, GameRegistryConsumer} from "../../traits/TraitsConsumer.sol";
import {IERC721BeforeTokenTransferHandler} from "../IERC721BeforeTokenTransferHandler.sol";

import {ERC721ContractURI} from "@proofofplay/erc721-extensions/src/ERC721ContractURI.sol";
import {ERC721OperatorFilter} from "@proofofplay/erc721-extensions/src/ERC721OperatorFilter.sol";
import {ERC721MirroredL2} from "@proofofplay/erc721-extensions/src/L2/ERC721MirroredL2.sol";

//todo: can we mix in mirrored on demand?
/** @title NFT base contract for all game NFTs. Exposes traits for the NFT and respects GameRegistry/Soulbound/LockingSystem access control */
contract GameNFTV2 is
    TraitsConsumer,
    ERC721OperatorFilter,
    ERC721MirroredL2,
    ERC721ContractURI,
    IGameNFTV2
{
    /// @notice Whether or not the token has had its traits initialized. Prevents re-initialization when bridging
    mapping(uint256 => bool) private _traitsInitialized;

    /// @notice Max supply for this NFT. If zero, it is unlimited supply.
    uint256 private immutable _maxSupply;

    /// @notice The amount of time a token has been held by a given account
    mapping(uint256 => mapping(address => uint32)) private _timeHeld;

    /// @notice Last transfer time for the token
    mapping(uint256 => uint32) public lastTransfer;

    /** ERRORS **/

    /// @notice Account must be non-null
    error InvalidAccountAddress();

    /// @notice Token id is not valid
    error InvalidTokenId();

    /// @notice tokenId exceeds max supply for this NFT
    error TokenIdExceedsMaxSupply();

    /// @notice Amount to mint exceeds max supply
    error NotEnoughSupply(uint256 needed, uint256 actual);

    /** EVENTS **/

    /// @notice Emitted when time held time is updated
    event TimeHeldSet(uint256 tokenId, address account, uint32 timeHeld);

    /// @notice Emitted when last transfer time is updated
    event LastTransferSet(uint256 tokenId, uint32 lastTransferTime);

    /** SETUP **/

    constructor(
        uint256 tokenMaxSupply,
        string memory name,
        string memory symbol,
        address gameRegistryAddress,
        uint256 id
    ) ERC721(name, symbol) TraitsConsumer(gameRegistryAddress, id) {
        _maxSupply = tokenMaxSupply;
    }

    /** @return Max supply for this token */
    function maxSupply() external view returns (uint256) {
        return _maxSupply;
    }

    /**
     * @param tokenId token id to check
     * @return Whether or not the given tokenId has been minted
     */
    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    /**
     * @return Generates a dynamic tokenURI based on the traits associated with the given token
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        // Make sure this still errors according to ERC721 spec
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        return _tokenURI(tokenId);
    }

    /**
     * @dev a method that bulk sets initialized imported NFTs
     * @param tokenIds List of TokenIds to be initialized
     */
    function setTraitsInitialized(
        uint256[] calldata tokenIds
    ) external onlyRole(MANAGER_ROLE) {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _traitsInitialized[tokenIds[i]] = true;
        }
    }

    /**
     * @param account Account to check hold time of
     * @param tokenId Id of the token
     * @return The time in seconds a given account has held a token
     */
    function getTimeHeld(
        address account,
        uint256 tokenId
    ) external view override returns (uint32) {
        address owner = ownerOf(tokenId);
        if (account == address(0)) {
            revert InvalidAccountAddress();
        }

        uint32 totalTime = _timeHeld[tokenId][account];

        if (owner == account) {
            uint32 lastTransferTime = lastTransfer[tokenId];
            uint32 currentTime = SafeCast.toUint32(block.timestamp);

            totalTime += (currentTime - lastTransferTime);
        }

        return totalTime;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(IERC165, ERC721, TraitsConsumer)
        returns (bool)
    {
        return
            interfaceId == type(IGameNFTV2).interfaceId ||
            TraitsConsumer.supportsInterface(interfaceId) ||
            ERC721.supportsInterface(interfaceId);
    }

    /** INTERNAL **/

    /** Initializes traits for the given tokenId */
    function _initializeTraits(uint256 tokenId) internal virtual {
        // Do nothing by default
    }

    /**
     * Mint token to recipient
     *
     * @param to        The recipient of the token
     * @param tokenId   Id of the token to mint
     */
    function _safeMint(address to, uint256 tokenId) internal override {
        if (_maxSupply != 0 && tokenId > _maxSupply) {
            revert TokenIdExceedsMaxSupply();
        }

        if (tokenId == 0) {
            revert InvalidTokenId();
        }

        super._safeMint(to, tokenId);

        // Conditionally initialize traits
        if (_traitsInitialized[tokenId] == false) {
            _initializeTraits(tokenId);
            _traitsInitialized[tokenId] = true;
        }
    }

    /**
     * @notice Checks for soulbound status before transfer
     * @inheritdoc ERC721
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override(ERC721MirroredL2, ERC721OperatorFilter) {
        // Track hold time
        for (uint256 idx = 0; idx < batchSize; idx++) {
            uint256 tokenId = firstTokenId + idx;
            uint32 lastTransferTime = lastTransfer[tokenId];
            uint32 currentTime = SafeCast.toUint32(block.timestamp);
            if (lastTransferTime > 0) {
                _timeHeld[tokenId][from] += (currentTime - lastTransferTime);
            }
            lastTransfer[tokenId] = currentTime;
        }

        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    /**
     * Message sender override to get Context to work with meta transactions
     *
     */
    function _msgSender()
        internal
        view
        override(Context, GameRegistryConsumer)
        returns (address)
    {
        return GameRegistryConsumer._msgSender();
    }

    /**
     * Message data override to get Context to work with meta transactions
     *
     */
    function _msgData()
        internal
        view
        override(Context, GameRegistryConsumer)
        returns (bytes calldata)
    {
        return GameRegistryConsumer._msgData();
    }

    function _checkRole(
        bytes32 role,
        address account
    ) internal view virtual override(GameRegistryConsumer, ERC721MirroredL2) {
        GameRegistryConsumer._checkRole(role, account);
    }

    function getLastTransfer(
        uint256 tokenId
    ) external view override returns (uint32) {
        return lastTransfer[tokenId];
    }

    function _setTimeHeld(
        uint256 tokenId,
        address account,
        uint32 timeHeld
    ) internal {
        _timeHeld[tokenId][account] = timeHeld;

        emit TimeHeldSet(tokenId, account, timeHeld);
    }

    function _setLastTransfer(
        uint256 tokenId,
        uint32 lastTransferTime
    ) internal {
        lastTransfer[tokenId] = lastTransferTime;

        emit LastTransferSet(tokenId, lastTransferTime);
    }
}
