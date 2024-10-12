// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";

import {EntityLibrary} from "../core/EntityLibrary.sol";

import {GameNFTV2Upgradeable, ITraitsProvider} from "./gamenft/GameNFTV2Upgradeable.sol";
import {GENERATION_TRAIT_ID, XP_TRAIT_ID, IS_PIRATE_TRAIT_ID, LEVEL_TRAIT_ID, NAME_TRAIT_ID} from "../Constants.sol";
import {MINTER_ROLE, TRUSTED_MIRROR_ROLE, GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import {BatchComponentData} from "../GameRegistry.sol";
import {SkinContainerComponent, Layout as SkinContainerComponentLayout, ID as SKIN_CONTAINER_COMPONENT_ID} from "../generated/components/SkinContainerComponent.sol";
import {PIRATE_SKIN_GUID} from "../skin/PirateSkinSystem.sol";
import {IGameItems, ID as GAME_ITEMS_CONTRACT_ID} from "../tokens/gameitems/IGameItems.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.piratenft"));

/** @title The latest PirateNFT */
contract PirateNFTL2 is GameNFTV2Upgradeable {
    using Strings for uint256;
    error InvalidInput();

    uint256 constant MAX_SUPPLY = 9999;

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

    /**
     * @notice Returns the total supply of the token
     */
    function totalSupply() public view virtual override returns (uint256) {
        return MAX_SUPPLY;
    }

    /**
     * @notice Used for bulk minting for initializing our migration
     * @param tokenIds  Array of tokenIds to mint
     * @param addresses Array of addresses to mint to
     */
    function claim(
        uint256[] calldata tokenIds,
        address[] calldata addresses
    ) external onlyRole(MINTER_ROLE) {
        if (tokenIds.length != addresses.length) {
            revert InvalidInput();
        }

        for (uint256 i = 0; i < tokenIds.length; ++i) {
            //todo: can we do optimizations
            if (tokenIds[i] == 0) {
                revert InvalidInput();
            }
            _safeMint(addresses[i], tokenIds[i]);
        }
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

    function batchSetTimeHeld(
        uint256[] calldata tokenIds,
        address[] calldata addresses,
        uint32[] calldata timeHeldValues
    ) external onlyRole(MINTER_ROLE) {
        if (
            tokenIds.length != addresses.length ||
            tokenIds.length != timeHeldValues.length
        ) {
            revert InvalidInput();
        }

        for (uint256 i = 0; i < tokenIds.length; ++i) {
            if (tokenIds[i] == 0) {
                revert InvalidInput();
            }
            // Migrate the amount of time a token has been held by a given account
            _setTimeHeld(tokenIds[i], addresses[i], timeHeldValues[i]);
        }
    }

    function batchSetLastTransfer(
        uint256[] calldata tokenIds,
        uint32[] calldata lastTransferValues
    ) external onlyRole(MINTER_ROLE) {
        if (tokenIds.length != lastTransferValues.length) {
            revert InvalidInput();
        }

        for (uint256 i = 0; i < tokenIds.length; ++i) {
            if (tokenIds[i] == 0) {
                revert InvalidInput();
            }
            // Migrate the last transfer time for the token
            _setLastTransfer(tokenIds[i], lastTransferValues[i]);
        }
    }

    function mirrorOwnershipWithComponentData(
        address from,
        address to,
        uint256 tokenId,
        BatchComponentData calldata data
    ) external onlyRole(TRUSTED_MIRROR_ROLE) {
        _gameRegistry.batchSetComponentValue(
            data.entities,
            data.componentIds,
            data.data
        );
        _mirrorOwnership(from, to, tokenId);
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
        for (uint256 i = 0; i < ids.length; ++i) {
            _burn(ids[i]);
        }
    }

    /**
     * @notice Add addtional logic handling for beforeTokenTransfer before passing to parent
     * @inheritdoc GameNFTV2Upgradeable
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override(GameNFTV2Upgradeable) {
        uint256 pirateEntity = EntityLibrary.tokenToEntity(
            address(this),
            firstTokenId
        );
        SkinContainerComponent skinContainerComponent = SkinContainerComponent(
            _gameRegistry.getComponent(SKIN_CONTAINER_COMPONENT_ID)
        );
        SkinContainerComponentLayout
            memory skinContainerLayout = skinContainerComponent.getLayoutValue(
                pirateEntity
            );
        // Mint equipped skin back to user
        for (uint256 i = 0; i < skinContainerLayout.slotEntities.length; i++) {
            if (skinContainerLayout.slotEntities[i] == PIRATE_SKIN_GUID) {
                (address itemTokenContract, uint256 itemTokenId) = EntityLibrary
                    .entityToToken(skinContainerLayout.skinEntities[i]);
                IGameItems(itemTokenContract).mint(from, itemTokenId, 1);
                skinContainerComponent.removeValueAtIndex(pirateEntity, i);
                break;
            }
        }

        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }
}
