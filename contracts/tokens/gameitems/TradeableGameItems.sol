// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import {IERC165, ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {Arrays} from "@openzeppelin/contracts/utils/Arrays.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {GameItems, MAX_TOKEN_ID} from "./GameItems.sol";
import {EntityLibrary} from "../../core/EntityLibrary.sol";
import {GameRegistryConsumerUpgradeable} from "../../GameRegistryConsumerUpgradeable.sol";
import {ID as GAME_ITEMS_ID} from "./IGameItems.sol";
import {GAME_LOGIC_CONTRACT_ROLE, MANAGER_ROLE} from "../../Constants.sol";
import {TokenReentrancyGuardUpgradable} from "../TokenReentrancyGuardUpgradable.sol";
import {TradeLicenseChecks} from "../TradeLicenseChecks.sol";
import {SOULBOUND_TRAIT_ID} from "../../Constants.sol";
import {ITraitsProvider, ID as TRAITS_PROVIDER_ID} from "../../interfaces/ITraitsProvider.sol";
import {TradeLicenseExemptComponent, ID as TRADE_LICENSE_EXEMPT_COMPONENT_ID} from "../../generated/components/TradeLicenseExemptComponent.sol";
import {TradeLibrary} from "../../trade/TradeLibrary.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {BanComponent, ID as BAN_COMPONENT_ID} from "../../generated/components/BanComponent.sol";
import {Banned} from "../../ban/BanSystem.sol";
import {ChainIdComponent, ID as CHAIN_ID_COMPONENT_ID} from "../../generated/components/ChainIdComponent.sol";
import {IMultichain1155} from "../IMultichain1155.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.tradeablegameitems")
);

address constant RECEIVER_WALLET = 0xEf438ccfFd1122D59c551836529d399b3E3B0347;
uint256 constant PERCENT_FEE = 1000;

/**
 * @title Tradeable Game Items
 * @dev Tradeable Game Items is a Marketplace optimized contract to display in-game items that are not trade locked.
 * @author Proof of Play
 */
contract TradeableGameItems is
    ERC165,
    IERC1155,
    TokenReentrancyGuardUpgradable,
    GameRegistryConsumerUpgradeable,
    TradeLicenseChecks,
    IMultichain1155,
    IERC2981
{
    using Arrays for uint256[];
    using Arrays for address[];

    mapping(address => mapping(address => bool)) private _operatorApprovals;

    uint256 public maxTokenId; // deprecated, replaced by UINT256_COMPONENT

    error ERC1155InvalidOperator(address operator);
    error ERC1155MissingApprovalForAll(address operator, address owner);
    error ERC1155InsufficientBalance(
        address sender,
        uint256 balance,
        uint256 needed,
        uint256 tokenId
    );

    error InvalidEventEmitter();
    error Soulbound();

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
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /** Royalty */

    /**
     * @inheritdoc IERC2981
     */
    function royaltyInfo(
        uint256,
        uint256 _salePrice
    ) public view virtual override returns (address, uint256) {
        // 10% royalty
        uint256 royaltyAmount = (_salePrice * PERCENT_FEE) / 10000;

        return (RECEIVER_WALLET, royaltyAmount);
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the same URI for *all* token types. It relies
     * on the token type ID substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * Clients calling this function must replace the `\{id\}` substring with the
     * actual token type ID.
     */
    function uri(uint256 id) public view virtual returns (string memory) {
        return GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID)).uri(id);
    }

    function balanceOf(
        address account,
        uint256 id
    ) external view override returns (uint256) {
        if (!_hasTradeLicense(account) && !_isTradeExempt(id)) {
            return 0;
        }

        return
            GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID)).balanceOf(
                account,
                id
            );
    }

    /** @return Token name for the given tokenId */
    function tokenName(uint256 tokenId) external view returns (string memory) {
        return
            GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID)).tokenName(
                tokenId
            );
    }

    /** @return Token name for the given tokenId */
    function tokenDescription(
        uint256 tokenId
    ) external view returns (string memory) {
        return
            GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID)).tokenDescription(
                tokenId
            );
    }

    /** @return Image URI for the given tokenId */
    function imageURI(uint256 tokenId) external view returns (string memory) {
        return
            GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID)).imageURI(tokenId);
    }

    /** @return External URI for the given tokenId */
    function externalURI(
        uint256 tokenId
    ) external view returns (string memory) {
        return
            GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID)).externalURI(
                tokenId
            );
    }

    /** @return Contract metadata URI */
    function contractURI() public view returns (string memory) {
        return GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID)).contractURI();
    }

    function sendEnableTradeLicenseEvents(
        address account
    ) public onlyRole(GAME_LOGIC_CONTRACT_ROLE) reentrantCheck {
        //reverts if no trade license
        _checkTradeLicense(account);

        GameItems gameItems = GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID));
        uint256[] memory ids = new uint256[](MAX_TOKEN_ID);
        uint256[] memory totalAmounts = new uint256[](MAX_TOKEN_ID);

        TradeLicenseExemptComponent tleComponent = TradeLicenseExemptComponent(
            _gameRegistry.getComponent(TRADE_LICENSE_EXEMPT_COMPONENT_ID)
        );

        uint256 nextIndex;
        uint256 bal;
        for (uint256 i = 1; i <= MAX_TOKEN_ID; i++) {
            bool isExempt = tleComponent.getValue(
                EntityLibrary.tokenToEntity(
                    _gameRegistry.getSystem(GAME_ITEMS_ID),
                    i
                )
            );
            // Skip if exempt or soulbound
            if (isExempt || _checkSoulbound(i) == true) {
                continue;
            }

            bal = gameItems.balanceOf(account, i);
            if (bal > 0) {
                ids[nextIndex] = i;
                totalAmounts[nextIndex] = bal;
                nextIndex++;
            }
        }
        uint256 reduceArrayLengthBy = MAX_TOKEN_ID - nextIndex;
        // resize ids array
        assembly {
            mstore(ids, sub(mload(ids), reduceArrayLengthBy))
        }
        // resize totalAmounts array
        assembly {
            mstore(totalAmounts, sub(mload(totalAmounts), reduceArrayLengthBy))
        }

        _emitTransferEvent(address(0x0), account, ids, totalAmounts);
    }

    /**
     * @dev Used by the GameItems BeforeTransferHandler.
     * @param from address minting item
     * @param to address receiving item
     * @param ids list of ids being minted
     * @param amounts amounts being minted
     */
    function emitTransferEvent(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external beforeTransferReentrantCheck {
        if (
            msg.sender !=
            GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID))
                .beforeTokenTransferHandler()
        ) {
            revert InvalidEventEmitter();
        }

        // Filter out any ids that are of soulbound items
        uint256 originalLength = ids.length;
        uint256 nextIndex;
        for (uint256 i = 0; i < ids.length; i++) {
            if (_checkSoulbound(ids[i]) == false) {
                ids[nextIndex] = ids[i];
                amounts[nextIndex] = amounts[i];
                nextIndex++;
            }
        }
        uint256 reduceArrayLengthBy = originalLength - nextIndex;
        // resize ids array
        assembly {
            mstore(ids, sub(mload(ids), reduceArrayLengthBy))
        }
        // resize amounts array
        assembly {
            mstore(amounts, sub(mload(amounts), reduceArrayLengthBy))
        }
        // Nothing to emit if all items were soulbound
        if (ids.length == 0) {
            return;
        }

        bool isTradeExempt = true;
        for (uint256 i; i < ids.length; i++) {
            if (!_isTradeExempt(ids[i])) {
                isTradeExempt = false;
                break;
            }
        }

        // sender doesnt have TL and item is not-trade-exempt, revert
        if (from != address(0) && !_hasTradeLicense(from) && !isTradeExempt) {
            return;
        }

        // receiver ineligble, acts as a burn then on our system;
        // sender does have TL
        // receiver does not have TL and item is not-trade-exempt, emit burn
        if (
            to != address(0) &&
            !_hasTradeLicense(to) &&
            !isTradeExempt &&
            _getChainId(to) == block.chainid
        ) {
            _emitTransferEvent(from, address(0), ids, amounts);
            return;
        }

        // sender has TL or item is trade exempt
        // receiver has TL or item is trade exempt
        // emit standard transfer
        _emitTransferOrMultichainTransfer(from, to, ids, amounts);
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(
        address account,
        address operator
    ) public view virtual returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata ids
    ) external view returns (uint256[] memory) {
        uint256[] memory balances = GameItems(
            _gameRegistry.getSystem(GAME_ITEMS_ID)
        ).balanceOfBatch(accounts, ids);

        for (uint256 i = 0; i < accounts.length; i++) {
            if (!_hasTradeLicense(accounts[i]) && !_isTradeExempt(ids[i])) {
                balances[i] = 0;
            }
        }

        return balances;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata
    ) external override reentrantCheck {
        _checkOwnership(from);
        _checkBalance(from, id, amount);
        // Revert if soulbound
        if (_checkSoulbound(id) == true) {
            revert Soulbound();
        }

        if (!_hasTradeLicense(from) && !_isTradeExempt(id)) {
            revert TradeLibrary.MissingTradeLicense();
        }

        // You can add logic here to ensure the transfer happens in the mirrored contract.
        // Or redirect the transfer to the original contract:
        GameItems gameItems = GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID));

        gameItems.burn(from, id, amount);

        // Mint the item unless there's a burn and its on the same chain
        if (to != address(0) && _getChainId(to) == block.chainid) {
            gameItems.mint(to, id, amount);
        }
        (uint256[] memory ids, uint256[] memory amounts) = _asSingletonArrays(
            id,
            amount
        );

        // If the recipent doesn't have trade license, we should emit an event that the item is burned. (So balances are kept on this contract)
        if (
            !_hasTradeLicense(to) &&
            !_isTradeExempt(id) &&
            _getChainId(to) == block.chainid
        ) {
            _emitTransferEvent(from, address(0), ids, amounts);
        } else {
            _emitTransferOrMultichainTransfer(from, to, ids, amounts);
        }
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `values` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external reentrantCheck {
        _checkOwnership(from);
        bool hasTradeLicense = _hasTradeLicense(from);

        for (uint256 i = 0; i < ids.length; i++) {
            if (!hasTradeLicense && !_isTradeExempt(ids[i])) {
                revert TradeLibrary.MissingTradeLicense();
            }
            _checkBalance(from, ids[i], amounts[i]);
            // Revert if soulbound
            if (_checkSoulbound(ids[i]) == true) {
                revert Soulbound();
            }
        }

        // You can add logic here to ensure the transfer happens in the mirrored contract.
        // Or redirect the transfer to the original contract:
        GameItems gameItems = GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID));

        gameItems.burnBatch(from, ids, amounts);

        // If it's a burn, we don't need to mint on the original contract
        // We only mint if it's on same chain, otherwise multichain takes over
        if (to != address(0) && _getChainId(to) == block.chainid) {
            gameItems.mintBatch(to, ids, amounts, data);
        }

        _filterAndEmit(from, to, ids, amounts);
    }

    /**
     * Used to rectify events from trade license exemption
     * This will be used by Admins to create 'burn' events for items that were transferred in error
     * that had trade license excemption.
     * Does not actually burn any items, but just emits the event so marketplaces can have correct totals.
     */
    function rectifyTransfers(
        address from,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external onlyRole(MANAGER_ROLE) {
        _emitTransferEvent(from, address(0), ids, amounts);
    }

    /**
     * Used to rectify events from trade license exemption, in batch format
     * This will be used by Admins to create 'burn' events for items that were transferred in error
     * that had trade license excemption.
     * Does not actually burn any items, but just emits the event so marketplaces can have correct totals.
     */
    function rectifyBatchTransfers(
        address[] calldata from,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external onlyRole(MANAGER_ROLE) {
        address operator = _msgSender();

        for (uint256 i = 0; i < from.length; i++) {
            emit TransferSingle(
                operator,
                from[i],
                address(0),
                ids[i],
                amounts[i]
            );
        }
    }

    /**
     * @inheritdoc IMultichain1155
     */
    function receivedMultichain1155TransferSingle(
        address to,
        uint256 id,
        uint256 amount
    ) external override {
        //can only be called from gameRegistry
        if (msg.sender != address(_gameRegistry)) {
            revert InvalidGameRegistry(msg.sender);
        }

        //mint the items
        GameItems gameItems = GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID));
        gameItems.mint(to, id, amount);
    }

    /**
     * @inheritdoc IMultichain1155
     */
    function receivedMultichain1155TransferBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external override {
        //can only be called from gameRegistry
        if (msg.sender != address(_gameRegistry)) {
            revert InvalidGameRegistry(msg.sender);
        }

        //mint the items
        GameItems gameItems = GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID));
        gameItems.mintBatch(to, ids, amounts, "");
    }

    // Internal
    /**
     * Checks if the token is soulbound or not and throws if it is.
     */
    //todo: move this under
    function _filterAndEmit(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) private {
        // filter out any Ids that are tade exempt
        uint256[] memory filteredIds = new uint256[](ids.length);
        uint256[] memory filteredAmounts = new uint256[](amounts.length);

        uint256 filteredIndex = 0;

        for (uint256 i = 0; i < ids.length; i++) {
            if (!_isTradeExempt(ids[i])) {
                filteredIds[filteredIndex] = ids[i];
                filteredAmounts[filteredIndex] = amounts[i];
                filteredIndex++;
            }
        }

        // Trim arrays
        assembly {
            mstore(filteredIds, filteredIndex)
            mstore(filteredAmounts, filteredIndex)
        }

        // If the reciever has no trade license, we want to emit an event that the item is burned. (So balances are kept on this contract)
        if (!_hasTradeLicense(to) && _getChainId(to) == block.chainid) {
            _emitTransferEvent(from, address(0), filteredIds, filteredAmounts);
        } else {
            _emitTransferOrMultichainTransfer(from, to, ids, amounts);
        }
    }

    function _emitTransferOrMultichainTransfer(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) private {
        uint256 chainId = _getChainId(to);

        if (chainId != block.chainid && to != address(0)) {
            //if user is not on same chain burn and do multichain transfer
            _emitTransferEvent(from, address(0), ids, amounts);
            if (ids.length == 1) {
                _gameRegistry.sendMultichain1155TransferSingle(
                    ID,
                    from,
                    to,
                    chainId,
                    ids[0],
                    amounts[0]
                );
            } else {
                _gameRegistry.sendMultichain1155TransferBatch(
                    ID,
                    from,
                    to,
                    chainId,
                    ids,
                    amounts
                );
            }
        } else {
            // Here we check if sender if so we burn and emit new event
            _emitTransferEvent(from, to, ids, amounts);
        }
    }

    function _checkSoulbound(uint256 tokenId) internal view returns (bool) {
        ITraitsProvider traitsProvider = ITraitsProvider(
            _gameRegistry.getSystem(TRAITS_PROVIDER_ID)
        );

        if (
            traitsProvider.getTraitBool(
                _gameRegistry.getSystem(GAME_ITEMS_ID),
                tokenId,
                SOULBOUND_TRAIT_ID
            ) == true
        ) {
            return true;
        }
        return false;
    }

    function _getChainId(address account) internal view returns (uint256) {
        return
            ChainIdComponent(_gameRegistry.getComponent(CHAIN_ID_COMPONENT_ID))
                .getValue(EntityLibrary.addressToEntity(account));
    }

    /**
     * @dev Verifies that the caller is the owner or operator for specific address
     * @param from address to check
     */
    function _checkOwnership(address from) internal view {
        if (_msgSender() != from && !_operatorApprovals[from][_msgSender()]) {
            revert ERC1155MissingApprovalForAll(_msgSender(), from);
        }

        if (
            BanComponent(_gameRegistry.getComponent(BAN_COMPONENT_ID)).getValue(
                EntityLibrary.addressToEntity(from)
            ) == true
        ) {
            revert Banned();
        }
    }

    /**
     * @dev Verifies the from address has the correct balance for id
     * @param from address
     * @param id token id
     * @param amount amount requried
     */
    function _checkBalance(
        address from,
        uint256 id,
        uint256 amount
    ) internal view {
        uint256 balance = GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID))
            .balanceOf(from, id);
        if (balance < amount) {
            revert ERC1155InsufficientBalance(from, balance, amount, id);
        }
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the zero address.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        if (operator == address(0)) {
            revert ERC1155InvalidOperator(address(0));
        }
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * Emits a transfer event for a token transfer
     * @param from address of the sender
     * @param to address of the receiver
     * @param ids a list of tokenIds to transfer
     * @param amounts a list of amounts to transfer
     */
    function _emitTransferEvent(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        address operator = _msgSender();

        if (from == to && from == address(0)) {
            return;
        }

        if (ids.length == 1) {
            emit TransferSingle(operator, from, to, ids[0], amounts[0]);
        } else {
            emit TransferBatch(operator, from, to, ids, amounts);
        }
    }

    /**
     * @dev Creates an array in memory with only one value for each of the elements provided.
     */
    function _asSingletonArrays(
        uint256 element1,
        uint256 element2
    ) private pure returns (uint256[] memory array1, uint256[] memory array2) {
        /// @solidity memory-safe-assembly
        assembly {
            // Load the free memory pointer
            array1 := mload(0x40)
            // Set array length to 1
            mstore(array1, 1)
            // Store the single element at the next word after the length (where content starts)
            mstore(add(array1, 0x20), element1)

            // Repeat for next array locating it right after the first array
            array2 := add(array1, 0x40)
            mstore(array2, 1)
            mstore(add(array2, 0x20), element2)

            // Update the free memory pointer by pointing after the second array
            mstore(0x40, add(array2, 0x40))
        }
    }

    function _isTradeExempt(uint256 id) private view returns (bool) {
        TradeLicenseExemptComponent tleComponent = TradeLicenseExemptComponent(
            _gameRegistry.getComponent(TRADE_LICENSE_EXEMPT_COMPONENT_ID)
        );
        return
            tleComponent.getValue(
                EntityLibrary.tokenToEntity(
                    _gameRegistry.getSystem(GAME_ITEMS_ID),
                    id
                )
            );
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}
