// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ContractTraits} from "../ContractTraits.sol";
import {ITokenURIHandler} from "../ITokenURIHandler.sol";
import {MANAGER_ROLE, ELEMENTAL_AFFINITY_TRAIT_ID, EXPERTISE_TRAIT_ID} from "../../Constants.sol";
import {IGameGlobals, ID as GAME_GLOBALS_ID} from "../../gameglobals/IGameGlobals.sol";
import {GameRegistryConsumerUpgradeable} from "../../GameRegistryConsumerUpgradeable.sol";
import {IHoldingSystem, ID as HOLDING_SYSTEM_ID} from "../../holding/IHoldingSystem.sol";
import {ITraitsConsumer} from "../../interfaces/ITraitsConsumer.sol";
import {ITraitsProvider, TokenURITrait, TraitDataType} from "../../interfaces/ITraitsProvider.sol";
import {NameComponent, ID as NameComponentId} from "../../generated/components/NameComponent.sol";
import {EntityLibrary} from "../../core/EntityLibrary.sol";
import {ELEMENTAL_AFFINITIES, EXPERTISE_VALUES} from "../starterpiratenft/StarterPirateNFTTokenURIHandler.sol";
import {LevelComponent, ID as LEVEL_COMPONENT_ID} from "../../generated/components/LevelComponent.sol";
import {XpComponent, ID as XP_COMPONENT_ID} from "../../generated/components/XpComponent.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.piratenfttokenurihandler")
);
uint256 constant PIRATE_NFT_IMAGES_ENHANCED_ID = uint256(
    keccak256("tokentype.piratenft.images.enhanced")
);

enum TokenTypeImage {
    IMAGE,
    ANIMATION_URL,
    MODEL_GLTF_URL,
    IMAGE_PNG_32,
    IMAGE_PNG_64,
    IMAGE_PNG_128,
    IMAGE_PNG_256,
    IMAGE_PNG_512,
    IMAGE_PNG_1024,
    IMAGE_PNG_2048
}

contract PirateNFTTokenURIHandler is
    GameRegistryConsumerUpgradeable,
    ContractTraits,
    ITokenURIHandler
{
    using Strings for uint256;

    /** SETUP **/

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /** EXTERNAL **/

    /**
     * @notice Generates metadata for the given tokenId
     * @param
     * @param tokenId  Token to generate metadata for
     * @return A normal URI
     */
    function tokenURI(
        address,
        address tokenContract,
        uint256 tokenId
    ) external view virtual override returns (string memory) {
        return
            _traitsProvider().generateTokenURI(
                tokenContract,
                tokenId,
                getExtraTraits(tokenContract, tokenId)
            );
    }

    /**
     * @dev This override includes the locked and soulbound traits
     * @param tokenId  Token to generate extra traits array for
     * @return Extra traits to include in the tokenURI metadata
     */
    function getExtraTraits(
        address tokenContract,
        uint256 tokenId
    ) public view returns (TokenURITrait[] memory) {
        ITraitsConsumer traitsConsumer = ITraitsConsumer(tokenContract);
        IHoldingSystem holdingSystem = IHoldingSystem(
            _getSystem(HOLDING_SYSTEM_ID)
        );

        // Fetch voxel pirate image URIs
        string[] memory baseImageURIs = IGameGlobals(
            _getSystem(GAME_GLOBALS_ID)
        ).getStringArray(PIRATE_NFT_IMAGES_ENHANCED_ID);

        string memory imageUri = string.concat(
            baseImageURIs[uint256(TokenTypeImage.IMAGE)],
            tokenId.toString()
        );
        uint256 entity = EntityLibrary.tokenToEntity(tokenContract, tokenId);

        uint256[] memory assetIds = this.getAssetTraitIds(tokenContract);
        uint8 numStaticTraits = 9;
        TokenURITrait[] memory extraTraits = new TokenURITrait[](
            numStaticTraits + assetIds.length
        );

        // Name
        extraTraits[0] = TokenURITrait({
            name: "name",
            value: _tokenName(tokenContract, tokenId),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: true,
            hidden: false
        });

        // Image
        extraTraits[1] = TokenURITrait({
            name: "image",
            value: abi.encode(imageUri),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: true,
            hidden: false
        });

        // Description
        extraTraits[2] = TokenURITrait({
            name: "description",
            value: abi.encode(traitsConsumer.tokenDescription(tokenId)),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: true,
            hidden: false
        });

        // External URL
        extraTraits[3] = TokenURITrait({
            name: "external_url",
            value: abi.encode(traitsConsumer.externalURI(tokenId)),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: true,
            hidden: false
        });

        // Holding
        extraTraits[4] = TokenURITrait({
            name: "Chests Claimed",
            isTopLevelProperty: false,
            dataType: TraitDataType.UINT,
            value: abi.encode(
                holdingSystem.milestonesClaimed(tokenContract, tokenId)
            ),
            hidden: false
        });

        // Elemental Affinity string
        extraTraits[5] = TokenURITrait({
            name: "Elemental Affinity",
            dataType: TraitDataType.STRING,
            value: _elementalAffinity(tokenContract, tokenId),
            isTopLevelProperty: false,
            hidden: false
        });

        // Expertise string
        extraTraits[6] = TokenURITrait({
            name: "Expertise",
            dataType: TraitDataType.STRING,
            value: _expertise(tokenContract, tokenId),
            isTopLevelProperty: false,
            hidden: false
        });

        // Level
        extraTraits[7] = TokenURITrait({
            name: "Level",
            dataType: TraitDataType.UINT,
            value: abi.encode(
                LevelComponent(_gameRegistry.getComponent(LEVEL_COMPONENT_ID))
                    .getValue(entity)
            ),
            isTopLevelProperty: false,
            hidden: false
        });

        // XP
        extraTraits[8] = TokenURITrait({
            name: "XP",
            dataType: TraitDataType.UINT,
            value: abi.encode(
                XpComponent(_gameRegistry.getComponent(XP_COMPONENT_ID))
                    .getValue(entity)
            ),
            isTopLevelProperty: false,
            hidden: false
        });

        // Assets
        TokenURITrait[] memory assetTraits = _getAssetTraits(
            tokenContract,
            tokenId,
            assetIds,
            baseImageURIs
        );
        for (uint256 idx = 0; idx < assetTraits.length; idx++) {
            extraTraits[numStaticTraits + idx] = assetTraits[idx];
        }

        return extraTraits;
    }

    /**
     * Adds a new asset type for a contract
     *
     * @param tokenContract Contract to add asset types for
     * @param asset         Asset to add to the contract
     */
    function addAsset(
        address tokenContract,
        Asset calldata asset
    ) external onlyRole(MANAGER_ROLE) {
        _addAsset(tokenContract, asset);
    }

    /**
     * Removes an asset from a contract
     *
     * @param tokenContract Contract to remove asset from
     * @param traitId       Keccak256 traitId of the asset to remove
     */
    function removeAsset(
        address tokenContract,
        uint256 traitId
    ) external onlyRole(MANAGER_ROLE) {
        _removeAsset(tokenContract, traitId);
    }

    /** INTERNAL **/

    function _getAssetUri(
        string[] memory baseImageURIs,
        Asset memory asset
    ) internal pure returns (string memory) {
        // Only PirateNFT's may have enhanced tokenType at the moment
        TokenTypeImage imageType;
        if (_compareStrings(asset.traitName, "image")) {
            imageType = TokenTypeImage.IMAGE;
        } else if (_compareStrings(asset.traitName, "animation_url")) {
            imageType = TokenTypeImage.ANIMATION_URL;
        } else if (_compareStrings(asset.traitName, "model_gltf_url")) {
            imageType = TokenTypeImage.MODEL_GLTF_URL;
        } else if (_compareStrings(asset.traitName, "image_png_32")) {
            imageType = TokenTypeImage.IMAGE_PNG_32;
        } else if (_compareStrings(asset.traitName, "image_png_64")) {
            imageType = TokenTypeImage.IMAGE_PNG_64;
        } else if (_compareStrings(asset.traitName, "image_png_128")) {
            imageType = TokenTypeImage.IMAGE_PNG_128;
        } else if (_compareStrings(asset.traitName, "image_png_256")) {
            imageType = TokenTypeImage.IMAGE_PNG_256;
        } else if (_compareStrings(asset.traitName, "image_png_512")) {
            imageType = TokenTypeImage.IMAGE_PNG_512;
        } else if (_compareStrings(asset.traitName, "image_png_1024")) {
            imageType = TokenTypeImage.IMAGE_PNG_1024;
        } else if (_compareStrings(asset.traitName, "image_png_2048")) {
            imageType = TokenTypeImage.IMAGE_PNG_2048;
        } else {
            return asset.uri;
        }

        if (uint256(imageType) < baseImageURIs.length) {
            string memory imageUri = baseImageURIs[uint256(imageType)];
            if (!_compareStrings(imageUri, "")) {
                return imageUri;
            }
        }

        return asset.uri;
    }

    function _getAssetTraits(
        address tokenContract,
        uint256 tokenId,
        uint256[] memory assetIds,
        string[] memory baseImageURIs
    ) internal view returns (TokenURITrait[] memory) {
        ContractInfo storage contractInfo = _contracts[tokenContract];

        // Iterate through assetIds building TokenURITrait structs
        TokenURITrait[] memory assetTraits = new TokenURITrait[](
            assetIds.length
        );

        for (uint256 idx = 0; idx < assetIds.length; idx++) {
            Asset storage asset = contractInfo.assets[assetIds[idx]];
            assetTraits[idx] = TokenURITrait({
                name: asset.traitName,
                isTopLevelProperty: true,
                dataType: TraitDataType.STRING,
                value: abi.encode(
                    string.concat(
                        _getAssetUri(baseImageURIs, asset),
                        tokenId.toString()
                    )
                ),
                hidden: false
            });
        }
        return assetTraits;
    }

    function _compareStrings(
        string memory a,
        string memory b
    ) internal pure returns (bool) {
        return (keccak256(bytes(a)) == keccak256(bytes(b)));
    }

    /**
     * @dev Handle NFT name field with component and fallback
     */
    function _tokenName(
        address tokenContract,
        uint256 tokenId
    ) internal view returns (bytes memory) {
        NameComponent nameComponent = NameComponent(
            _gameRegistry.getComponent(NameComponentId)
        );
        uint256 entity = EntityLibrary.tokenToEntity(tokenContract, tokenId);
        if (nameComponent.has(entity)) {
            return nameComponent.getBytes(entity);
        }
        string memory pirateName = string(
            abi.encodePacked("Founder's Pirate #", tokenId.toString())
        );
        return abi.encode(pirateName);
    }

    /**
     * @dev Handle NFT Elemental Affinity string field
     */
    function _elementalAffinity(
        address tokenContract,
        uint256 tokenId
    ) internal view returns (bytes memory) {
        ITraitsProvider traitsProvider = _traitsProvider();
        // Account for having no elemental affinity
        if (
            !traitsProvider.hasTrait(
                tokenContract,
                tokenId,
                ELEMENTAL_AFFINITY_TRAIT_ID
            )
        ) {
            return abi.encode("");
        }
        uint256 affinityId = traitsProvider.getTraitUint256(
            tokenContract,
            tokenId,
            ELEMENTAL_AFFINITY_TRAIT_ID
        );
        string[] memory affinitiesArray = IGameGlobals(
            _getSystem(GAME_GLOBALS_ID)
        ).getStringArray(ELEMENTAL_AFFINITIES);
        string memory elementalAffinity = affinitiesArray[affinityId - 1];
        return abi.encode(elementalAffinity);
    }

    /**
     * @dev Handle NFT Expertise string field
     */
    function _expertise(
        address tokenContract,
        uint256 tokenId
    ) internal view returns (bytes memory) {
        ITraitsProvider traitsProvider = _traitsProvider();
        // Account for having no expertise
        if (
            !traitsProvider.hasTrait(tokenContract, tokenId, EXPERTISE_TRAIT_ID)
        ) {
            return abi.encode("");
        }
        uint256 expertiseId = _traitsProvider().getTraitUint256(
            tokenContract,
            tokenId,
            EXPERTISE_TRAIT_ID
        );
        string[] memory expertiseArray = IGameGlobals(
            _getSystem(GAME_GLOBALS_ID)
        ).getStringArray(EXPERTISE_VALUES);
        string memory expertise = expertiseArray[expertiseId - 1];
        return abi.encode(expertise);
    }
}
