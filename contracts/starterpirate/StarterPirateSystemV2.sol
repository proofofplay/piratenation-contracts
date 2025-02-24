// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {MINTER_ROLE, MANAGER_ROLE, VRF_SYSTEM_ROLE, XP_TRAIT_ID, LEVEL_TRAIT_ID} from "../Constants.sol";
import {RandomLibrary} from "../libraries/RandomLibrary.sol";
import {StarterPirateNFT, ID as STARTER_PIRATE_NFT_ID} from "../tokens/starterpiratenft/StarterPirateNFT.sol";
import {ILootCallbackV2} from "../loot/ILootCallbackV2.sol";
import {IERC165, GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {TokenIdLibrary} from "../core/TokenIdLibrary.sol";

import {StaticEntityListComponent, ID as STATIC_ENTITY_LIST_COMPONENT_ID} from "../generated/components/StaticEntityListComponent.sol";
import {MintedStarterPirateComponent, Layout as MintedStarterPirateComponentStruct, ID as MINTED_STARTER_PIRATE_COMPONENT_ID} from "../generated/components/MintedStarterPirateComponent.sol";
import {NameComponent, ID as NAME_COMPONENT_ID, Layout as NameComponentLayout} from "../generated/components/NameComponent.sol";
import {MixinComponent, ID as MIXIN_COMPONENT_ID} from "../generated/components/MixinComponent.sol";
import {MintCounterComponent, ID as MINT_COUNTER_COMPONENT_ID} from "../generated/components/MintCounterComponent.sol";
import {GenerationComponent, ID as GENERATION_COMPONENT_ID} from "../generated/components/GenerationComponent.sol";
import {DiceRollComponent, ID as DICE_ROLL_COMPONENT_ID} from "../generated/components/DiceRollComponent.sol";
import {ExpertiseComponent, ID as EXPERTISE_COMPONENT_ID} from "../generated/components/ExpertiseComponent.sol";
import {AffinityComponent, ID as AFFINITY_COMPONENT_ID} from "../generated/components/AffinityComponent.sol";
import {StarSignComponent, ID as STAR_SIGN_COMPONENT_ID} from "../generated/components/StarSignComponent.sol";
import {LevelComponent, ID as LEVEL_COMPONENT_ID} from "../generated/components/LevelComponent.sol";
import {XpComponent, ID as XP_COMPONENT_ID} from "../generated/components/XpComponent.sol";
import {IsPirateComponent, ID as IS_PIRATE_COMPONENT_ID} from "../generated/components/IsPirateComponent.sol";
import {StringArrayComponent, ID as STRING_ARRAY_COMPONENT_ID} from "../generated/components/StringArrayComponent.sol";
import {BatchComponentData} from "../GameRegistry.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.starterpiratesystem.v2")
);

uint256 constant STAR_SIGN_GAME_GLOBALS_ID = uint256(
    keccak256("game.piratenation.global.traits.starsign")
);

uint256 constant RANDOM_PIRATE_ENTITY = uint256(
    keccak256("game.piratenation.starterpiratesystem.random")
);

bytes32 constant API_MINTER_ROLE = keccak256("API_MINTER_ROLE");

/**
 * @title StarterPirateSystemV2
 * @dev Used for minting starter pirate NFTs and generating their randomized traits
 */
contract StarterPirateSystemV2 is
    GameRegistryConsumerUpgradeable,
    ILootCallbackV2
{
    using Strings for uint256;
    /** STRUCTS */

    // VRFRequest: Struct to track and respond to VRF requests
    struct VRFRequest {
        address account;
        uint256 tokenId;
        uint256 lootId;
    }

    /** MEMBERS */

    /// @notice Mapping to track VRF requests
    mapping(uint256 => VRFRequest) private _vrfRequests;

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
        MintCounterComponent(
            _gameRegistry.getComponent(MINT_COUNTER_COMPONENT_ID)
        ).setValue(ID, newCount);
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
        _mintAndInitializeStarterPirate(account, tokenTemplateId, 1, true);
    }

    /**
     * @inheritdoc ILootCallbackV2
     */
    function grantLoot(
        address account,
        uint256 lootId,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        _mintAndInitializeStarterPirate(account, lootId, amount, false);
    }

    /**
     * @inheritdoc ILootCallbackV2
     */
    function grantLootWithRandomWord(
        address account,
        uint256 lootId,
        uint256 amount,
        uint256 randomWord
    ) external onlyRole(MINTER_ROLE) whenNotPaused returns (uint256) {
        if (account == address(0) || randomWord == 0) {
            revert InvalidParams();
        }
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        _updateUserMintedCount(accountEntity, 1, false);

        MintCounterComponent mintCounterComponent = MintCounterComponent(
            _gameRegistry.getComponent(MINT_COUNTER_COMPONENT_ID)
        );
        uint256 currentNftId = mintCounterComponent.getValue(ID);

        for (uint256 idx = 0; idx < amount; idx++) {
            // Increment current token id to next id
            currentNftId++;

            // Handle mint
            randomWord = _handleMintAndInitializeStarterPirate(
                currentNftId,
                lootId,
                randomWord,
                account
            );
        }

        mintCounterComponent.setValue(ID, currentNftId);

        return randomWord;
    }

    /**
     * @dev Helper batch mint function
     */
    function batchMintStarterPirates(
        address[] calldata accounts,
        uint256[] calldata tokenIds
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        if (accounts.length == 0 || accounts.length != tokenIds.length) {
            revert InvalidParams();
        }
        StarterPirateNFT starterPirateNFT = StarterPirateNFT(
            _getSystem(STARTER_PIRATE_NFT_ID)
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            starterPirateNFT.mint(accounts[i], tokenIds[i]);
        }
    }

    /**
     * @notice Callback function used by VRF Coordinator
     */
    function randomNumberCallback(
        uint256 requestId,
        uint256 randomNumber
    ) external override onlyRole(VRF_SYSTEM_ROLE) {
        VRFRequest storage request = _vrfRequests[requestId];
        if (request.account != address(0)) {
            // Set template ID
            _handleMintAndInitializeStarterPirate(
                request.tokenId,
                request.lootId,
                randomNumber,
                request.account
            );

            // Delete the VRF request
            delete _vrfRequests[requestId];
        }
    }

    /** @return Whether or not this callback needs randomness */
    function needsVRF() external pure returns (bool) {
        return true;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165) returns (bool) {
        return interfaceId == type(ILootCallbackV2).interfaceId;
    }

    function migrationMint(
        address account,
        uint256 tokenId,
        BatchComponentData calldata data
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        StarterPirateNFT starterPirateNFT = StarterPirateNFT(
            _getSystem(STARTER_PIRATE_NFT_ID)
        );

        starterPirateNFT.mint(account, tokenId);
        _gameRegistry.batchSetComponentValue(
            data.entities,
            data.componentIds,
            data.data
        );
    }

    /** INTERNAL **/

    /**
     * Uses VRF callback to call StarterPirateNFT contract to mint a starterpirate NFT
     * @param account       Account to mint to
     * @param lootId        Token template id to mint
     */
    function _mintAndInitializeStarterPirate(
        address account,
        uint256 lootId,
        uint256 amount,
        bool enforceSingle
    ) internal {
        if (account == address(0) || amount == 0) {
            revert InvalidParams();
        }
        // Use MintedStarterPirateComponent to check if caller
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        _updateUserMintedCount(accountEntity, amount, enforceSingle);
        // Check that TokenTemplate exists and is in the correct range

        MintCounterComponent mintCounterComponent = MintCounterComponent(
            _gameRegistry.getComponent(MINT_COUNTER_COMPONENT_ID)
        );
        uint256 currentNftId = mintCounterComponent.getValue(ID);

        _checkValidLootId(lootId);

        for (uint256 idx = 0; idx < amount; idx++) {
            // Increment current token id to next id
            currentNftId++;

            // Request VRF
            VRFRequest storage vrfRequest = _vrfRequests[
                _requestRandomNumber(0)
            ];
            vrfRequest.account = account;
            vrfRequest.tokenId = currentNftId;
            vrfRequest.lootId = lootId;
        }

        mintCounterComponent.setValue(ID, currentNftId);
    }

    function _handleMintAndInitializeStarterPirate(
        uint256 _tokenId,
        uint256 lootId,
        uint256 randomWord,
        address account
    ) internal returns (uint256) {
        StarterPirateNFT starterPirateNFT = StarterPirateNFT(
            _getSystem(STARTER_PIRATE_NFT_ID)
        );

        // Mint starter pirate NFT
        uint256 tokenId = TokenIdLibrary.generateTokenId(_tokenId);
        starterPirateNFT.mint(account, tokenId);

        uint256 entity = EntityLibrary.tokenToEntity(
            address(starterPirateNFT),
            tokenId
        );

        // Set mixin
        MixinComponent mixinComponent = MixinComponent(
            _gameRegistry.getComponent(MIXIN_COMPONENT_ID)
        );

        if (lootId == RANDOM_PIRATE_ENTITY) {
            uint256[] memory mixinOptions = StaticEntityListComponent(
                _gameRegistry.getComponent(STATIC_ENTITY_LIST_COMPONENT_ID)
            ).getValue(ID);
            lootId = mixinOptions[randomWord % mixinOptions.length];
        }
        _checkValidMixin(lootId);

        uint256[] memory mixins = new uint256[](1);
        mixins[0] = lootId;
        mixinComponent.setValue(entity, mixins);

        // Name trait component
        string memory pirateName = string(
            abi.encodePacked("Pirate #", tokenId.toString())
        );
        NameComponent(_gameRegistry.getComponent(NAME_COMPONENT_ID)).setValue(
            entity,
            pirateName
        );

        // Set dynamic traits
        randomWord = _setDynamicTraits(randomWord, entity);
        // Set static traits
        _setStaticTraits(entity);

        return randomWord;
    }

    /**
     * @notice Use VRF to set randomized trait values
     * @param randomWord        Random word to use for generating traits
     * @param entity            Entity to set traits for
     *
     * @return Updated random word
     */
    function _setDynamicTraits(
        uint256 randomWord,
        uint256 entity
    ) internal returns (uint256) {
        // Generate a new random word and set it as the expertise
        randomWord = RandomLibrary.generateNextRandomWord(randomWord);
        ExpertiseComponent(_gameRegistry.getComponent(EXPERTISE_COMPONENT_ID))
            .setValue(entity, (randomWord % 5) + 1);

        // Generate a new random word and set it as the affinity
        randomWord = RandomLibrary.generateNextRandomWord(randomWord);
        AffinityComponent(_gameRegistry.getComponent(AFFINITY_COMPONENT_ID))
            .setValue(entity, SafeCast.toUint8((randomWord % 5) + 1));

        // Generate a new random word and set it as dice roll 1 and 2
        randomWord = RandomLibrary.generateNextRandomWord(randomWord);
        uint8 diceRoll1 = SafeCast.toUint8((randomWord % 6) + 1);
        randomWord = RandomLibrary.generateNextRandomWord(randomWord);
        DiceRollComponent(_gameRegistry.getComponent(DICE_ROLL_COMPONENT_ID))
            .setValue(
                entity,
                diceRoll1,
                SafeCast.toUint8((randomWord % 6) + 1)
            );

        // Generate a new random word and set it as STAR_SIGN_TRAIT_ID
        randomWord = RandomLibrary.generateNextRandomWord(randomWord);
        string[] memory starSigns = StringArrayComponent(
            _gameRegistry.getComponent(STRING_ARRAY_COMPONENT_ID)
        ).getValue(STAR_SIGN_GAME_GLOBALS_ID);
        StarSignComponent(_gameRegistry.getComponent(STAR_SIGN_COMPONENT_ID))
            .setValue(entity, (randomWord % (starSigns.length - 1)) + 1);

        return randomWord;
    }

    /**
     * @notice Set static traits for a token
     * @param entity Token entity to set traits for
     */
    function _setStaticTraits(uint256 entity) internal {
        // Generation component
        GenerationComponent(_gameRegistry.getComponent(GENERATION_COMPONENT_ID))
            .setValue(entity, 1);

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

        // Is pirate
        IsPirateComponent(_gameRegistry.getComponent(IS_PIRATE_COMPONENT_ID))
            .setValue(entity, true);
    }
    function _isValidMixin(uint256 mixinEntity) internal view returns (bool) {
        uint256[] memory validMixinList = StaticEntityListComponent(
            _gameRegistry.getComponent(STATIC_ENTITY_LIST_COMPONENT_ID)
        ).getValue(ID);
        for (uint256 i = 0; i < validMixinList.length; i++) {
            if (validMixinList[i] == mixinEntity) {
                return true;
            }
        }
        return false;
    }

    function _checkValidLootId(uint256 lootId) internal view {
        if (_isValidMixin(lootId) || (lootId == RANDOM_PIRATE_ENTITY)) {
            return;
        }
        revert TemplateNotFound();
    }

    function _checkValidMixin(uint256 mixinEntity) internal view {
        if (!_isValidMixin(mixinEntity)) {
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
