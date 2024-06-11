// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {MINTER_ROLE, MANAGER_ROLE, IS_PIRATE_TRAIT_ID, RANDOMIZER_ROLE, ELEMENTAL_AFFINITY_TRAIT_ID, EXPERTISE_TRAIT_ID, GENERATION_TRAIT_ID, LEVEL_TRAIT_ID, XP_TRAIT_ID} from "../Constants.sol";
import {RandomLibrary} from "../libraries/RandomLibrary.sol";
import {StarterPirateNFT, ID as STARTER_PIRATE_NFT_ID} from "../tokens/starterpiratenft/StarterPirateNFT.sol";
import {ILootCallback} from "../loot/ILootCallback.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {ITraitsProvider, ID as TRAITS_PROVIDER_ID} from "../interfaces/ITraitsProvider.sol";
import {ITokenTemplateSystem, ID as TOKEN_TEMPLATE_SYSTEM_ID} from "../tokens/ITokenTemplateSystem.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {IGameGlobals, ID as GAME_GLOBALS_ID} from "../gameglobals/IGameGlobals.sol";
import {LevelComponent, ID as LEVEL_COMPONENT_ID} from "../generated/components/LevelComponent.sol";
import {XpComponent, ID as XP_COMPONENT_ID} from "../generated/components/XpComponent.sol";

import {LootTableComponentV3Old, Layout as LootTableComponentStruct, ID as LOOT_TABLE_V3_OLD_COMPONENT_ID} from "../generated/components/LootTableComponentV3Old.sol";
import {MintedStarterPirateComponent, Layout as MintedStarterPirateComponentStruct, ID as MINTED_STARTER_PIRATE_COMPONENT_ID} from "../generated/components/MintedStarterPirateComponent.sol";
import {NameComponent, ID as NameComponentId, Layout as NameComponentLayout} from "../generated/components/NameComponent.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.starterpiratesystem")
);

uint256 constant IS_STARTER_PIRATE_TRAIT_ID = uint256(
    keccak256("is_starter_pirate")
);

uint256 constant HAS_PIRATE_SOUL_TRAIT_ID = uint256(
    keccak256("has_pirate_soul")
);

uint256 constant DICE_ROLL_1_TRAIT_ID = uint256(keccak256("Dice Roll 1"));
uint256 constant DICE_ROLL_2_TRAIT_ID = uint256(keccak256("Dice Roll 2"));
uint256 constant STAR_SIGN_TRAIT_ID = uint256(keccak256("Star Sign"));

uint256 constant STAR_SIGN_GAME_GLOBALS_ID = uint256(
    keccak256("traits.starsign")
);

bytes32 constant API_MINTER_ROLE = keccak256("API_MINTER_ROLE");

/**
 * @title StarterPirateSystem
 * @dev Used for minting starter pirate NFTs and generating their randomized traits
 */
contract StarterPirateSystem is GameRegistryConsumerUpgradeable, ILootCallback {
    using Strings for uint256;
    /** STRUCTS */

    // VRFRequest: Struct to track and respond to VRF requests
    struct VRFRequest {
        address account;
        uint256 tokenId;
        uint256 templateId;
    }

    /** MEMBERS */

    /// @notice Mapping to track VRF requests
    mapping(uint256 => VRFRequest) private _vrfRequests;

    /// @notice Current token id counter
    uint256 public currentNftId;

    /** ERRORS **/

    /// @notice Invalid params
    error InvalidParams();

    /// @notice Template not found
    error TemplateNotFound();

    /// @notice Already minted a starter pirate
    error AlreadyMintedStarterPirate(uint256 accountEntity);

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * Updates the current token id counter
     * @param newCount      New count to set
     */
    function updateCurrentPirateIdCount(
        uint256 newCount
    ) external onlyRole(MANAGER_ROLE) {
        currentNftId = newCount;
    }

    /**
     * @dev User triggered function to mint a single starter pirate
     * @param tokenTemplateId TokenTemplate Id to use for the starter pirate
     * @param wallet Wallet to mint to
     */
    function grantStarterPirate(
        uint256 tokenTemplateId,
        address wallet
    ) external whenNotPaused onlyRole(API_MINTER_ROLE) {
        address account = _getPlayerAccount(wallet);
        _grantLoot(account, tokenTemplateId, 1, true);
    }

    /**
     * @dev LootCallback function to mint starter pirates
     * @param account address to mint to
     * @param tokenTemplateId TokenTemplate Id to use for the starter pirate
     * @param amount Amount to mint
     */
    function grantLoot(
        address account,
        uint256 tokenTemplateId,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        _grantLoot(account, tokenTemplateId, amount, false);
    }

    function grantLootWithRandomWord(
        address account,
        uint256 tokenTemplateId,
        uint256 randomWord
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        if (account == address(0) || tokenTemplateId == 0 || randomWord == 0) {
            revert InvalidParams();
        }
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        _updateUserMintedCount(accountEntity, 1, false);
        // Check that TokenTemplate exists and is in the correct range
        _checkValidTemplateId(tokenTemplateId);
        currentNftId++;
        uint256 tokenId = currentNftId;
        // Handle mint
        _handleMint(tokenId, tokenTemplateId, randomWord, account);
    }

    /**
     * @dev Helper batch mint function
     */
    function batchMint(
        address[] calldata accounts,
        uint256[] calldata tokenIds,
        uint256[] calldata tokenTemplateIds
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        if (
            accounts.length == 0 ||
            accounts.length != tokenTemplateIds.length ||
            accounts.length != tokenIds.length
        ) {
            revert InvalidParams();
        }
        StarterPirateNFT starterPirateNFT = StarterPirateNFT(
            _getSystem(STARTER_PIRATE_NFT_ID)
        );
        ITokenTemplateSystem tokenTemplateSystem = ITokenTemplateSystem(
            _getSystem(TOKEN_TEMPLATE_SYSTEM_ID)
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            starterPirateNFT.mint(accounts[i], tokenIds[i]);
            tokenTemplateSystem.setTemplate(
                address(starterPirateNFT),
                tokenIds[i],
                tokenTemplateIds[i]
            );
        }
    }

    /**
     * @notice Callback function used by VRF Coordinator
     */
    function fulfillRandomWordsCallback(
        uint256 requestId,
        uint256[] memory randomWords
    ) external override onlyRole(RANDOMIZER_ROLE) {
        VRFRequest storage request = _vrfRequests[requestId];
        if (request.account != address(0)) {
            uint256 randomWord = randomWords[0];
            // Set template ID
            _handleMint(
                request.tokenId,
                request.templateId,
                randomWord,
                request.account
            );

            // Delete the VRF request
            delete _vrfRequests[requestId];
        }
    }

    /** INTERNAL **/

    /**
     * @notice Use VRF to set randomized trait values
     * @param traitsProvider       TraitsProvider contract
     * @param randomWord        Random word to use for generating traits
     * @param starterPirateNft  StarterPirateNFT contract
     * @param tokenId           Token id to set traits for
     */
    function _setDynamicTraits(
        ITraitsProvider traitsProvider,
        uint256 randomWord,
        address starterPirateNft,
        uint256 tokenId
    ) internal {
        // Generate a new random word and set it as the expertise
        randomWord = RandomLibrary.generateNextRandomWord(randomWord);
        traitsProvider.setTraitUint256(
            starterPirateNft,
            tokenId,
            EXPERTISE_TRAIT_ID,
            (randomWord % 5) + 1
        );
        // Generate a new random word and set it as the affinity
        randomWord = RandomLibrary.generateNextRandomWord(randomWord);
        traitsProvider.setTraitUint256(
            starterPirateNft,
            tokenId,
            ELEMENTAL_AFFINITY_TRAIT_ID,
            (randomWord % 5) + 1
        );
        // Generate a new random word and set it as DICE_ROLL_1_TRAIT_ID
        randomWord = RandomLibrary.generateNextRandomWord(randomWord);
        traitsProvider.setTraitUint256(
            starterPirateNft,
            tokenId,
            DICE_ROLL_1_TRAIT_ID,
            (randomWord % 6) + 1
        );
        // Generate a new random word and set it as DICE_ROLL_2_TRAIT_ID
        randomWord = RandomLibrary.generateNextRandomWord(randomWord);
        traitsProvider.setTraitUint256(
            starterPirateNft,
            tokenId,
            DICE_ROLL_2_TRAIT_ID,
            (randomWord % 6) + 1
        );
        // Generate a new random word and set it as STAR_SIGN_TRAIT_ID
        randomWord = RandomLibrary.generateNextRandomWord(randomWord);
        string[] memory starSigns = IGameGlobals(_getSystem(GAME_GLOBALS_ID))
            .getStringArray(STAR_SIGN_GAME_GLOBALS_ID);
        string memory randStarSign = starSigns[randomWord % starSigns.length];
        traitsProvider.setTraitString(
            starterPirateNft,
            tokenId,
            STAR_SIGN_TRAIT_ID,
            randStarSign
        );
    }

    /**
     * @notice Set static traits for a token
     * @param traitsProvider       TraitsProvider contract
     * @param starterPirateNft  StarterPirateNFT contract
     * @param tokenId           Token id to set traits for
     */
    function _setStaticTraits(
        ITraitsProvider traitsProvider,
        address starterPirateNft,
        uint256 tokenId
    ) internal {
        // Generation trait
        traitsProvider.setTraitUint256(
            starterPirateNft,
            tokenId,
            GENERATION_TRAIT_ID,
            1
        );
        // XP trait
        traitsProvider.setTraitUint256(
            starterPirateNft,
            tokenId,
            XP_TRAIT_ID,
            0
        );
        // Level trait
        traitsProvider.setTraitUint256(
            starterPirateNft,
            tokenId,
            LEVEL_TRAIT_ID,
            1
        );
        // Is Pirate trait
        traitsProvider.setTraitBool(
            starterPirateNft,
            tokenId,
            IS_PIRATE_TRAIT_ID,
            true
        );
        // Is Starter Pirate trait
        traitsProvider.setTraitBool(
            starterPirateNft,
            tokenId,
            IS_STARTER_PIRATE_TRAIT_ID,
            true
        );
        // Has Pirate Soul trait
        traitsProvider.setTraitBool(
            starterPirateNft,
            tokenId,
            HAS_PIRATE_SOUL_TRAIT_ID,
            false
        );

        uint256 entity = EntityLibrary.tokenToEntity(starterPirateNft, tokenId);

        // Name trait component
        string memory pirateName = string(
            abi.encodePacked("Pirate #", tokenId.toString())
        );
        NameComponent(_gameRegistry.getComponent(NameComponentId)).setValue(
            entity,
            pirateName
        );

        // Level component
        LevelComponent(_gameRegistry.getComponent(LEVEL_COMPONENT_ID)).setValue(
                entity,
                1
            );

        // XP component
        XpComponent(_gameRegistry.getComponent(XP_COMPONENT_ID)).setValue(
            entity,
            0
        );
    }

    /**
     * Uses VRF callback to call StarterPirateNFT contract to mint a starterpirate NFT
     * @param account       Account to mint to
     * @param tokenTemplateId        Token template id to mint
     */
    function _grantLoot(
        address account,
        uint256 tokenTemplateId,
        uint256 amount,
        bool enforceSingle
    ) internal {
        if (tokenTemplateId == 0 || account == address(0) || amount == 0) {
            revert InvalidParams();
        }
        // Use MintedStarterPirateComponent to check if caller
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        _updateUserMintedCount(accountEntity, amount, enforceSingle);
        // Check that TokenTemplate exists and is in the correct range
        _checkValidTemplateId(tokenTemplateId);

        for (uint256 idx = 0; idx < amount; idx++) {
            // Increment current token id to next id
            currentNftId++;

            uint256 tokenId = currentNftId;

            // Request VRF
            VRFRequest storage vrfRequest = _vrfRequests[
                _requestRandomWords(1)
            ];
            vrfRequest.account = account;
            vrfRequest.tokenId = tokenId;
            vrfRequest.templateId = tokenTemplateId;
        }
    }

    function _handleMint(
        uint256 tokenId,
        uint256 tokenTemplateId,
        uint256 randomWord,
        address account
    ) internal {
        // Get TraitsProvider
        ITraitsProvider traitsProvider = _traitsProvider();
        StarterPirateNFT starterPirateNFT = StarterPirateNFT(
            _getSystem(STARTER_PIRATE_NFT_ID)
        );
        // Set template ID
        ITokenTemplateSystem(_getSystem(TOKEN_TEMPLATE_SYSTEM_ID)).setTemplate(
            address(starterPirateNFT),
            tokenId,
            tokenTemplateId
        );
        // Set dynamic traits
        _setDynamicTraits(
            traitsProvider,
            randomWord,
            address(starterPirateNFT),
            tokenId
        );
        // Set static traits
        _setStaticTraits(traitsProvider, address(starterPirateNFT), tokenId);
        // Mint starter pirate NFT
        starterPirateNFT.mint(account, tokenId);
    }

    function _checkValidTemplateId(uint256 tokenTemplateId) internal view {
        LootTableComponentStruct memory lootTable = LootTableComponentV3Old(
            _gameRegistry.getComponent(LOOT_TABLE_V3_OLD_COMPONENT_ID)
        ).getLayoutValue(ID);
        bool validTokenTemplateId = false;
        for (uint256 i = 0; i < lootTable.lootIds.length; i++) {
            if (lootTable.lootIds[i] == tokenTemplateId) {
                validTokenTemplateId = true;
                break;
            }
        }
        if (
            validTokenTemplateId == false ||
            ITokenTemplateSystem(_getSystem(TOKEN_TEMPLATE_SYSTEM_ID)).exists(
                tokenTemplateId
            ) ==
            false
        ) {
            revert TemplateNotFound();
        }
    }

    function _updateUserMintedCount(
        uint256 accountEntity,
        uint256 amount,
        bool enforceSingle
    ) internal {
        // Get MintedStarterPirateComponent
        MintedStarterPirateComponent mintedStarterPirateComponent = MintedStarterPirateComponent(
                _gameRegistry.getComponent(MINTED_STARTER_PIRATE_COMPONENT_ID)
            );
        uint256 mintedAmount = mintedStarterPirateComponent.getValue(
            accountEntity
        );
        if (enforceSingle && mintedAmount > 0) {
            revert AlreadyMintedStarterPirate(accountEntity);
        }
        mintedAmount += amount;
        // Mark off that this account has minted a starter pirate
        mintedStarterPirateComponent.setValue(accountEntity, mintedAmount);
    }
}
