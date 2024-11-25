// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import {ERC1155Upgradeable, ContextUpgradeable, IERC1155Upgradeable, IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

import {MANAGER_ROLE, MINTER_ROLE, GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";
import {IGameItems, ID} from "./IGameItems.sol";

import {TraitsConsumerUpgradeable, GameRegistryConsumerUpgradeable} from "../../traits/TraitsConsumerUpgradeable.sol";

import {IERC1155BeforeTokenTransferHandler} from "../IERC1155BeforeTokenTransferHandler.sol";
import {ChainIdComponent, ID as CHAIN_ID_COMPONENT_ID} from "../../generated/components/ChainIdComponent.sol";
import {EntityLibrary} from "../../core/EntityLibrary.sol";

uint256 constant MAX_TOKEN_ID = 1000;

/** @title ERC1155 contract for Game Items */
contract GameItems is
    TraitsConsumerUpgradeable,
    IGameItems,
    ERC1155Upgradeable
{
    /** TYPES **/
    struct TypeInfo {
        bool recyclable; //deprecated
        uint256 mints;
        uint256 burns;
        uint256 maxSupply; //deprecated
    }

    /** MEMBERS **/

    /// @notice Supply info for each type
    mapping(uint256 => TypeInfo) private typeInfo;

    /// @notice Current contract metadata URI for this contract
    string private _contractURI;

    /// @notice Handler for before token transfer events
    address public beforeTokenTransferHandler;

    /** EVENTS **/

    /// @notice Emitted when contractURI has changed
    event ContractURIUpdated(string uri);

    /// @notice Everytime max supply is updated, this event is emitted. Can be used to track all items in the game
    event TypeUpdated(uint256 indexed id, uint256 maxSupply, bool recyclable);

    /** ERRORS **/

    /// @notice maxSupply needs to be higher than minted
    error MaxSupplyTooLow(uint256 needed, uint256 actual);

    /// @notice Token type has not been defined
    error InvalidTokenId();

    /// @notice Amount to mint exceeds max supply
    error NotEnoughSupply(uint256 needed, uint256 actual);

    /** SETUP **/

    constructor() {
        // Do nothing
    }

    /**
     * Initializer function for upgradeable contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        _defaultDescription = "Take to the seas with your pirate crew! Explore the world and gather XP, loot, and untold riches in a race to become the world's greatest pirate captain! Play at https://piratenation.game";

        TraitsConsumerUpgradeable.__TraitsConsumer_init(
            gameRegistryAddress,
            ID
        );
        ERC1155Upgradeable.__ERC1155_init("");
    }

    /** EXTERNAL **/

    /**
     * Sets the current contractURI for the contract
     *
     * @param _uri New contract URI
     */
    function setContractURI(
        string calldata _uri
    ) public onlyRole(MANAGER_ROLE) {
        _contractURI = _uri;
        emit ContractURIUpdated(_uri);
    }

    /**
     * @return Contract metadata URI for the NFT contract, used by NFT marketplaces to display collection inf
     */
    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    /**
     * Sets a mintable token type up
     *
     * @param id            Id of the token type to setup
     * @param maxSupply     Max Supply of the stoken
     * @param recyclable    Whether or not burns put tokens back into the pool to be minted again
     */
    function setType(
        uint256 id,
        uint256 maxSupply,
        bool recyclable
    ) external onlyRole(MANAGER_ROLE) {
        uint256 mints = typeInfo[id].mints;
        if (mints > maxSupply) {
            revert MaxSupplyTooLow(mints, maxSupply);
        }
        typeInfo[id].maxSupply = maxSupply;
        typeInfo[id].recyclable = recyclable;

        emit TypeUpdated(id, maxSupply, recyclable);
    }

    /**
     * Mints a ERC1155 token
     *
     * @param to        Recipient of the token
     * @param id        Id of token to mint
     * @param amount    Quantity of token to mint
     */
    function mint(
        address to,
        uint256 id,
        uint256 amount
    ) external override onlyRole(MINTER_ROLE) whenNotPaused {
        if (id > MAX_TOKEN_ID) {
            revert InvalidTokenId();
        }
        _safeMint(to, id, amount);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        _mintBatch(to, ids, amounts, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        _mintBatch(to, ids, amounts, "");
    }

    /**
     * Burn a token - any payment / game logic should be handled in the game contract.
     *
     * @param from      Account to burn from
     * @param id        Id of the token to burn
     * @param amount    Quantity to burn
     */
    function burn(
        address from,
        uint256 id,
        uint256 amount
    ) external override onlyRole(GAME_LOGIC_CONTRACT_ROLE) whenNotPaused {
        typeInfo[id].burns += amount;
        _burn(from, id, amount);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external onlyRole(GAME_LOGIC_CONTRACT_ROLE) whenNotPaused {
        for (uint256 i = 0; i < ids.length; i++) {
            typeInfo[ids[i]].burns += amounts[i];
        }
        _burnBatch(from, ids, amounts);
    }

    /**
     * @param id Id of the token type to get supply info for
     *
     * @return Returns the current supply information for the given type
     */
    function getInfoForType(
        uint256 id
    ) external view returns (TypeInfo memory) {
        if (typeInfo[id].maxSupply == 0) {
            revert InvalidTokenId();
        }
        return typeInfo[id];
    }

    /** @return Token metadata URI for the given Id */
    function uri(uint256 id) public view override returns (string memory) {
        return _tokenURI(id);
    }

    /**
     * @param id  Id of the type to get data for
     *
     * @return How many of the given token id have been minted
     */
    function minted(
        uint256 id
    ) external view virtual override(IGameItems) returns (uint256) {
        return typeInfo[id].mints;
    }

    /**
     * Sets the before token transfer handler
     *
     * @param handlerAddress  Address to the transfer hook handler contract
     */
    function setBeforeTokenTransferHandler(
        address handlerAddress
    ) external onlyRole(MANAGER_ROLE) {
        beforeTokenTransferHandler = handlerAddress;
    }

    /**
     * @inheritdoc IERC165Upgradeable
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(
            IERC165Upgradeable,
            TraitsConsumerUpgradeable,
            ERC1155Upgradeable
        )
        returns (bool)
    {
        return
            IERC165Upgradeable(this).supportsInterface(interfaceId) ||
            TraitsConsumerUpgradeable.supportsInterface(interfaceId) ||
            ERC1155Upgradeable.supportsInterface(interfaceId);
    }

    /*** INTERNAL ***/

    // Executes the mint with appropriate checks and locking
    function _safeMint(address to, uint256 id, uint256 amount) internal {
        TypeInfo storage typeData = typeInfo[id];

        typeData.mints += amount;
        _mint(to, id, amount, "");
    }

    /**
     * @notice Additional checks to prevent transfer of soulbound items, locked tokems, etc.
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        if (beforeTokenTransferHandler != address(0)) {
            IERC1155BeforeTokenTransferHandler handlerRef = IERC1155BeforeTokenTransferHandler(
                    beforeTokenTransferHandler
                );
            handlerRef.beforeTokenTransfer(
                address(this),
                operator,
                from,
                to,
                ids,
                amounts,
                data
            );
        }

        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function _afterTokenTransfer(
        address,
        address,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory
    ) internal virtual override {
        if (
            to != address(0) &&
            ChainIdComponent(_gameRegistry.getComponent(CHAIN_ID_COMPONENT_ID))
                .getValue(EntityLibrary.addressToEntity(to)) !=
            block.chainid
        ) {
            for (uint256 i = 0; i < ids.length; i++) {
                typeInfo[ids[i]].burns += amounts[i];
            }
            // User is on another chain, burn items as they will be minted there by Multichain System
            _burnBatch(to, ids, amounts);
        }
    }

    /**
     * Message sender override to get Context to work with meta transactions
     *
     */
    function _msgSender()
        internal
        view
        override(ContextUpgradeable, GameRegistryConsumerUpgradeable)
        returns (address)
    {
        return GameRegistryConsumerUpgradeable._msgSender();
    }

    /**
     * Message data override to get Context to work with meta transactions
     *
     */
    function _msgData()
        internal
        view
        override(ContextUpgradeable, GameRegistryConsumerUpgradeable)
        returns (bytes calldata)
    {
        return GameRegistryConsumerUpgradeable._msgData();
    }
}
