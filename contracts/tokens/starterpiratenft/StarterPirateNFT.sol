// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Strings.sol";

import {GameNFTV2Upgradeable} from "../gamenft/GameNFTV2Upgradeable.sol";
import {NAME_TRAIT_ID, MINTER_ROLE, GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.starterpiratenft"));

/** @title Starter Gen1 Pirate NFTs on L2 */
contract StarterPirateNFT is GameNFTV2Upgradeable {
    using Strings for uint256;

    // 0 max supply = infinite
    uint256 constant MAX_SUPPLY = 0;

    /** SETUP */
    constructor() {
        // Do nothing
    }

    function initialize(address gameRegistryAddress) public initializer {
        _defaultDescription = "Take to the seas with your pirate crew! Explore the world and gather XP, loot, and untold riches in a race to become the world's greatest pirate captain! Play at https://piratenation.game";
        _defaultImageURI = "ipfs://QmUeMG7QPySPiBp4hTc9u1FPcq5MKJzyYLgQh1t7FefECX?";
        __GameNFTV2Upgradeable_init(
            MAX_SUPPLY,
            "Pirate",
            "PIRATE",
            gameRegistryAddress,
            ID
        );
    }

    /** Initializes traits for the given tokenId */
    function _initializeTraits(uint256 tokenId) internal override {}

    /** @return Token name for the given tokenId */
    function tokenName(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        if (_hasTrait(tokenId, NAME_TRAIT_ID) == true) {
            // If token has a name trait set, use that
            return _getTraitString(tokenId, NAME_TRAIT_ID);
        } else {
            return string(abi.encodePacked("Pirate #", tokenId.toString()));
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
}
