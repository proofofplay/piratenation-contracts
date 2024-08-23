// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Strings.sol";

import {GameNFTV2Upgradeable, ITraitsProvider} from "../gamenft/GameNFTV2Upgradeable.sol";
import {GENERATION_TRAIT_ID, LEVEL_TRAIT_ID, NAME_TRAIT_ID, IS_SHIP_TRAIT_ID, MINTER_ROLE, GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";
import {ChainIdComponent, ID as CHAIN_ID_COMPONENT_ID} from "../../generated/components/ChainIdComponent.sol";
import {EntityLibrary} from "../../core/EntityLibrary.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.shipnft"));

/** @title Pirate NFTs on L2 */
contract ShipNFT is GameNFTV2Upgradeable {
    using Strings for uint256;

    // 0 max supply = infinite
    uint256 constant MAX_SUPPLY = 0;

    error InvalidInput();

    /** SETUP */
    constructor() {
        // Do nothing
    }

    function initialize(address gameRegistryAddress) public initializer {
        _defaultDescription = "Take to the seas with your pirate crew! Explore the world and gather XP, loot, and untold riches in a race to become the world's greatest pirate captain! Play at https://piratenation.game";
        _defaultImageURI = "ipfs://QmUeMG7QPySPiBp4hTc9u1FPcq5MKJzyYLgQh1t7FefECX?";
        __GameNFTV2Upgradeable_init(
            MAX_SUPPLY,
            "Ship",
            "SHIP",
            gameRegistryAddress,
            ID
        );
    }

    /** Initializes traits for the given tokenId */
    function _initializeTraits(uint256 tokenId) internal override {
        ITraitsProvider traitsProvider = _traitsProvider();

        traitsProvider.setTraitBool(
            address(this),
            tokenId,
            IS_SHIP_TRAIT_ID,
            true
        );
    }

    /** @return Token name for the given tokenId */
    function tokenName(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        if (_hasTrait(tokenId, NAME_TRAIT_ID) == true) {
            // If token has a name trait set, use that
            return _getTraitString(tokenId, NAME_TRAIT_ID);
        } else {
            return string(abi.encodePacked("Ship #", tokenId.toString()));
        }
    }

    /**
     * Mints the ERC721 token
     *
     * @param to        Recipient of the token
     * @param id        Id of token to mint
     */
    function mint(
        address to,
        uint256 id
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        _safeMint(to, id);
    }

    /**
     * Burn a token - any payment / game logic should be handled in the game contract.
     *
     * @param id        Id of the token to burn
     */
    function burn(
        uint256 id
    ) external onlyRole(GAME_LOGIC_CONTRACT_ROLE) whenNotPaused {
        _burn(id);
    }

    /**
     * Burn multiple tokens in batches
     *
     * @param ids        Ids of the tokens to burn
     */
    function burnBatch(
        uint256[] memory ids
    ) external onlyRole(GAME_LOGIC_CONTRACT_ROLE) whenNotPaused {
        if (ids.length == 0) {
            revert InvalidInput();
        }
        for (uint256 i = 0; i < ids.length; i++) {
            _burn(ids[i]);
        }
    }
    
    function _afterTokenTransfer(
        address,
        address to,
        uint256 tokenId,
        uint256
    ) internal virtual override {
        if (
            to != address(0) &&
            ChainIdComponent(_gameRegistry.getComponent(CHAIN_ID_COMPONENT_ID))
                .getValue(EntityLibrary.addressToEntity(to)) !=
            block.chainid
        ) {
            // User is on another chain, burn items as they will be minted there by Multichain System
            _burn(tokenId);
        }
    }
}
