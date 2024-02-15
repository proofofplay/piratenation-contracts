// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";

import "./GameNFT.sol";
import {GENERATION_TRAIT_ID, XP_TRAIT_ID, IS_PIRATE_TRAIT_ID, LEVEL_TRAIT_ID, NAME_TRAIT_ID} from "../Constants.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.piratenft"));

/** @title Pirate NFTs on L2
 * deprecated: Please use PirateNFTL2 instead for future tx.
 */
contract PirateNFT is GameNFT {
    using Strings for uint256;

    uint256 constant MAX_SUPPLY = 10000;

    constructor(address gameRegistryAddress)
        GameNFT(MAX_SUPPLY, "Pirate", "PIRATE", gameRegistryAddress, ID)
    {
        _defaultDescription = "Take to the seas with your pirate crew! Explore the world and gather XP, loot, and untold riches in a race to become the world's greatest pirate captain! Play at https://piratenation.game";
        _defaultImageURI = "ipfs://QmUeMG7QPySPiBp4hTc9u1FPcq5MKJzyYLgQh1t7FefECX?";
    }

    /** Initializes traits for the given tokenId */
    function _initializeTraits(uint256 tokenId) internal override {
        ITraitsProvider traitsProvider = _traitsProvider();

        traitsProvider.setTraitUint256(
            address(this),
            tokenId,
            GENERATION_TRAIT_ID,
            0
        );

        traitsProvider.setTraitUint256(address(this), tokenId, XP_TRAIT_ID, 0);

        traitsProvider.setTraitUint256(
            address(this),
            tokenId,
            LEVEL_TRAIT_ID,
            1
        );

        traitsProvider.setTraitBool(
            address(this),
            tokenId,
            IS_PIRATE_TRAIT_ID,
            true
        );
    }

    /** @return Token name for the given tokenId */
    function tokenName(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        if (_hasTrait(tokenId, NAME_TRAIT_ID) == true) {
            // If token has a name trait set, use that
            return _getTraitString(tokenId, NAME_TRAIT_ID);
        } else {
            return string(abi.encodePacked("Pirate #", tokenId.toString()));
        }
    }
}
