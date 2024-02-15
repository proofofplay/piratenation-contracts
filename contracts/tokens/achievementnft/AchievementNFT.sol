// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "../../deprecated/GameNFT.sol";

import {MINTER_ROLE, GAME_LOGIC_CONTRACT_ROLE, NAME_TRAIT_ID, SOULBOUND_TRAIT_ID} from "../../Constants.sol";
import {ID} from "./IAchievementNFT.sol";

contract AchievementNFT is GameNFT {
    using Strings for uint256;

    // 0 max supply = infinite
    uint256 constant MAX_SUPPLY = 0;

    constructor(
        address gameRegistryAddress
    )
        GameNFT(
            MAX_SUPPLY,
            "Pirate Nation Achievement",
            "PNA",
            gameRegistryAddress,
            ID
        )
    {
        _defaultDescription = "Take to the seas with your pirate crew! Explore the world and gather XP, loot, and untold riches in a race to become the world's greatest pirate captain! Play at https://piratenation.game";
        _defaultImageURI = "ipfs://QmSjSWojiBfGeFox5r5k3a3x2u9ARKBsbKjLbaQgc7PfMV";
    }

    /** Initializes traits for the given tokenId */
    function _initializeTraits(uint256 tokenId) internal override {
        ITraitsProvider traitsProvider = _traitsProvider();

        traitsProvider.setTraitBool(
            address(this),
            tokenId,
            SOULBOUND_TRAIT_ID,
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
            // TODO: Determine default naming scheme.
            return "Pirate Nation Achievement";
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
     *
     * @param id        Id of the token to burn
     */
    function burn(
        uint256 id
    ) external onlyRole(GAME_LOGIC_CONTRACT_ROLE) whenNotPaused {
        _burn(id);
    }
}
