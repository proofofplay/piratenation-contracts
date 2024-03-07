// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import {IERC165, ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {TradeLibrary} from "../../trade/TradeLibrary.sol";
import {EntityLibrary} from "../../core/EntityLibrary.sol";
import {ShipNFT, ID as SHIP_NFT_ID} from "./ShipNFT.sol";
import {GameRegistryConsumerUpgradeable} from "../../GameRegistryConsumerUpgradeable.sol";
import {TradeLicenseComponent, ID as TRADE_LICENSE_COMPONENT_ID} from "../../generated/components/TradeLicenseComponent.sol";
import {ITokenTemplateSystem, ID as TOKEN_TEMPLATE_SYSTEM_ID} from "../ITokenTemplateSystem.sol";
import {TradeLicenseChecks} from "../TradeLicenseChecks.sol";
import {TokenReentrancyGuardUpgradable} from "../TokenReentrancyGuardUpgradable.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";

import {GAME_LOGIC_CONTRACT_ROLE, SOULBOUND_TRAIT_ID, MANAGER_ROLE} from "../../Constants.sol";

import {IERC721Errors} from "../IERC721Errors.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.tradeableshipnft"));

address constant RECEIVER_WALLET = 0xEf438ccfFd1122D59c551836529d399b3E3B0347;
uint256 constant PERCENT_FEE = 1000;

/**
 * @title Tradeable ShipNFT
 * @dev Tradeable ShipNFT  is a Marketplace optimized contract to display in-game items that are not trade locked.
 * @author Proof of Play
 */
contract TradeableShipNFT is
    ERC165,
    IERC721,
    IERC721Metadata,
    TokenReentrancyGuardUpgradable,
    GameRegistryConsumerUpgradeable,
    IERC721Errors,
    TradeLicenseChecks,
    IERC2981
{
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    error InvalidEventEmitter();

    error InvalidValues();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
        __TokenReentrancyGuard_init();
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC721Enumerable).interfaceId ||
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /** Royalty */

    /**
     * @inheritdoc IERC2981
     */
    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) public view virtual override returns (address, uint256) {
        // 10% royalty
        uint256 royaltyAmount = (_salePrice * PERCENT_FEE) / 10000;

        return (RECEIVER_WALLET, royaltyAmount);
    }

    /** Regular stuff */
    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view returns (string memory) {
        return ShipNFT(_gameRegistry.getSystem(SHIP_NFT_ID)).name();
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view returns (string memory) {
        return ShipNFT(_gameRegistry.getSystem(SHIP_NFT_ID)).symbol();
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view returns (string memory) {
        return ShipNFT(_gameRegistry.getSystem(SHIP_NFT_ID)).tokenURI(tokenId);
    }

    /** @return Token name for the given tokenId */
    function tokenName(uint256 tokenId) public view returns (string memory) {
        return ShipNFT(_gameRegistry.getSystem(SHIP_NFT_ID)).tokenName(tokenId);
    }

    /**
     * @return Contract metadata URI for the NFT contract, used by NFT marketplaces to display collection inf
     */
    function contractURI() public view returns (string memory) {
        return ShipNFT(_gameRegistry.getSystem(SHIP_NFT_ID)).contractURI();
    }

    /** @return Image URI for the given tokenId */
    function imageURI(uint256 tokenId) external view returns (string memory) {
        return ShipNFT(_gameRegistry.getSystem(SHIP_NFT_ID)).imageURI(tokenId);
    }

    /** @return External URI for the given tokenId */
    function externalURI(
        uint256 tokenId
    ) external view returns (string memory) {
        return
            ShipNFT(_gameRegistry.getSystem(SHIP_NFT_ID)).externalURI(tokenId);
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public {
        address owner = _ownerOf(tokenId);
        address auth = _msgSender();

        if (
            auth != address(0) &&
            owner != auth &&
            !isApprovedForAll(owner, auth)
        ) {
            revert ERC721InvalidApprover(auth);
        }

        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(
        uint256 tokenId
    ) public view override returns (address) {
        _requireMinted(tokenId);

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual {
        address owner = _msgSender();
        if (operator == address(0)) {
            revert ERC721InvalidOperator(operator);
        }
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(
        address owner,
        address operator
    ) public view virtual returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function sendEnableTradeLicenseEvents(
        address account
    ) public onlyRole(GAME_LOGIC_CONTRACT_ROLE) reentrantCheck {
        //reverts if no trade license
        _checkTradeLicense(account);
        // Get the balance of the account
        ShipNFT shipNFT = ShipNFT(_gameRegistry.getSystem(SHIP_NFT_ID));
        uint256 amount = shipNFT.balanceOf(account);

        // todo: is there a way we can combine to one transfer event?
        uint256 shipTokenIdByIndex;
        ITokenTemplateSystem tokenTemplateSystem = ITokenTemplateSystem(
            _gameRegistry.getSystem(TOKEN_TEMPLATE_SYSTEM_ID)
        );
        for (uint256 i = 0; i < amount; i++) {
            shipTokenIdByIndex = tokenOfOwnerByIndex(account, i);
            // Check if soulbound and skip if it is
            if (
                _checkIfSoulbound(tokenTemplateSystem, shipTokenIdByIndex) ==
                false
            ) {
                _emitTransferEvent(address(0x0), account, shipTokenIdByIndex);
            }
        }
    }

    /**
     * @dev Used by the GameItems BeforeTransferHandler.
     * @param from address minting item
     * @param to address receiving item
     * @param firstTokenId TokenId being minted
     * @param batchSize the size of the batch
     */
    function emitTransferEvent(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) external beforeTransferReentrantCheck {
        if (
            msg.sender !=
            ShipNFT(_gameRegistry.getSystem(SHIP_NFT_ID))
                .beforeTokenTransferHandler()
        ) {
            revert InvalidEventEmitter();
        }

        if (from == address(0) && to == address(0)) {
            revert InvalidValues();
        }

        ITokenTemplateSystem tokenTemplateSystem = ITokenTemplateSystem(
            _gameRegistry.getSystem(TOKEN_TEMPLATE_SYSTEM_ID)
        );

        // If receiver doesnt have a TL, we emit a burn, skip soulbound ships
        if (to != address(0) && !_hasTradeLicense(to)) {
            for (uint256 i = 0; i < batchSize; i++) {
                if (
                    _checkIfSoulbound(tokenTemplateSystem, firstTokenId + i) ==
                    false
                ) {
                    _emitTransferEvent(from, address(0), firstTokenId + i);
                }
            }
            return;
        }
        // Otherwise emit standard transfer event, skip soulbound ships
        for (uint256 i = 0; i < batchSize; i++) {
            if (
                _checkIfSoulbound(tokenTemplateSystem, firstTokenId + i) ==
                false
            ) {
                _emitTransferEvent(from, to, firstTokenId + i);
            }
        }
    }

    /**
     * @dev Used to batch emit transfer events for migration purposes
     */
    function batchEmitMigrationTransfer(
        uint256[] calldata tokenIds,
        address[] calldata owners
    ) external onlyRole(MANAGER_ROLE) {
        ShipNFT shipNFT = ShipNFT(_gameRegistry.getSystem(SHIP_NFT_ID));
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (shipNFT.ownerOf(tokenIds[i]) == owners[i]) {
                _emitTransferEvent(address(0), owners[i], tokenIds[i]);
            }
        }
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual reentrantCheck {
        _transferFrom(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public reentrantCheck {
        _safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual reentrantCheck {
        _safeTransferFrom(from, to, tokenId, data);
    }

    /**
     * Gets the balance of Tradeable ShipNFTs
     * @param account The account that owns nft
     */
    function balanceOf(address account) external view returns (uint256) {
        if (!_hasTradeLicense(account)) {
            return 0;
        }

        return ShipNFT(_gameRegistry.getSystem(SHIP_NFT_ID)).balanceOf(account);
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view override returns (address) {
        address owner = _ownerOf(tokenId);
        if (_hasTradeLicense(owner)) {
            return owner;
        }
        return address(0);
    }

    /** ERC721Enumerable */
    function tokenOfOwnerByIndex(
        address owner,
        uint256 index
    ) public view returns (uint256) {
        return
            ShipNFT(_gameRegistry.getSystem(SHIP_NFT_ID)).tokenOfOwnerByIndex(
                owner,
                index
            );
    }

    function totalSupply() public view returns (uint256) {
        return ShipNFT(_gameRegistry.getSystem(SHIP_NFT_ID)).totalSupply();
    }

    function tokenByIndex(uint256 index) public view returns (uint256) {
        return
            ShipNFT(_gameRegistry.getSystem(SHIP_NFT_ID)).tokenByIndex(index);
    }

    // Internal
    /**
     * @dev Returns whether `spender` is allowed to manage `owner`'s tokens, or `tokenId` in
     * particular (ignoring whether it is owned by `owner`).
     *
     * WARNING: This function assumes that `owner` is the actual owner of `tokenId` and does not
     * verify this assumption.
     */
    function _isAuthorized(
        address owner,
        address spender,
        uint256 tokenId
    ) internal view virtual returns (bool) {
        return
            spender != address(0) &&
            (owner == spender ||
                isApprovedForAll(owner, spender) ||
                getApproved(tokenId) == spender);
    }

    function _checkOwnership(uint256 tokenId) private view {
        address owner = _ownerOf(tokenId); // thist hrows invalid token if it's to 0
        address spender = _msgSender();

        if (!_isAuthorized(owner, spender, tokenId)) {
            revert ERC721InsufficientApproval(spender, tokenId);
        }
    }

    function _requireMinted(uint256 tokenId) private view {
        _ownerOf(tokenId); //does revert check in child token;
    }

    function _ownerOf(uint256 tokenId) private view returns (address) {
        return ShipNFT(_gameRegistry.getSystem(SHIP_NFT_ID)).ownerOf(tokenId);
    }

    /**
     * Emits a transfer event for a token transfer
     * @param from address of the sender
     * @param to address of the receiver
     * @param tokenId a list of tokenIds to transfer
     */
    function _emitTransferEvent(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Private function to invoke {IERC721Receiver-onERC721Received} on a target address. This will revert if the
     * recipient doesn't accept the token transfer. The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try
                IERC721Receiver(to).onERC721Received(
                    _msgSender(),
                    from,
                    tokenId,
                    data
                )
            returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert ERC721InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert ERC721InvalidReceiver(to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    /**
     * @dev Checks if the ship is soulbound
     */
    function _checkIfSoulbound(
        ITokenTemplateSystem tokenTemplateSystem,
        uint256 tokenId
    ) internal view returns (bool) {
        ShipNFT shipNFT = ShipNFT(_gameRegistry.getSystem(SHIP_NFT_ID));

        if (
            tokenTemplateSystem.hasTrait(
                address(shipNFT),
                tokenId,
                SOULBOUND_TRAIT_ID
            ) &&
            tokenTemplateSystem.getTraitBool(
                address(shipNFT),
                tokenId,
                SOULBOUND_TRAIT_ID
            ) ==
            true
        ) {
            return true;
        }
        return false;
    }

    /**
     * @dev Underlying safeTransferFrom logic
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal {
        _transferFrom(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    /**
     * @dev Underlying transferFrom logic
     */
    function _transferFrom(address from, address to, uint256 tokenId) internal {
        _checkOwnership(tokenId);
        _checkTradeLicense(from);

        ShipNFT shipNFT = ShipNFT(_gameRegistry.getSystem(SHIP_NFT_ID));
        shipNFT.burn(tokenId);

        // Mint the item unless there's a burn
        if (to != address(0)) {
            shipNFT.mint(to, tokenId);
        }

        // If the recipent doesn't have trade license, we should emit an event that the item is burned. (So balances are kept on this contract)
        if (!_hasTradeLicense(to)) {
            to = address(0);
        }

        _emitTransferEvent(from, to, tokenId);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}
