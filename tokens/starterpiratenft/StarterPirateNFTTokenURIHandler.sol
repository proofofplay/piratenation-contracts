// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ContractTraits} from "../ContractTraits.sol";
import {ITokenURIHandler} from "../ITokenURIHandler.sol";
import {MANAGER_ROLE, NAME_TRAIT_ID, IMAGE_TRAIT_ID, DESCRIPTION_TRAIT_ID, ELEMENTAL_AFFINITY_TRAIT_ID, EXPERTISE_TRAIT_ID} from "../../Constants.sol";
import {IGameGlobals, ID as GAME_GLOBALS_ID} from "../../gameglobals/IGameGlobals.sol";
import {GameRegistryConsumerUpgradeable} from "../../GameRegistryConsumerUpgradeable.sol";
import {IHoldingSystem, ID as HOLDING_SYSTEM_ID} from "../../holding/IHoldingSystem.sol";
import {ITraitsConsumer} from "../../interfaces/ITraitsConsumer.sol";
import {TokenURITrait, TraitDataType} from "../../interfaces/ITraitsProvider.sol";
import {ITokenTemplateSystem} from "../../tokens/ITokenTemplateSystem.sol";
import {ID as TOKEN_TEMPLATE_SYSTEM_ID} from "../../tokens/ITokenTemplateSystem.sol";
import {NameComponent, ID as NameComponentId, Layout as NameComponentLayout} from "../../generated/components/NameComponent.sol";
import {DescriptionComponent, ID as DescriptionComponentId, Layout as DescriptionComponentLayout} from "../../generated/components/DescriptionComponent.sol";
import {EntityLibrary} from "../../core/EntityLibrary.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.starterpiratenfttokenurihandler")
);
uint256 constant STARTER_PIRATE_NFT_IMAGES_ENHANCED_ID = uint256(
    keccak256("tokentype.starterpiratenft.images.enhanced")
);

// Global : Starter Pirate NFT description
uint256 constant STARTER_PIRATE_DESCRIPTION = uint256(
    keccak256("starter_pirate_description")
);

// Global : Elemental Affinities
uint256 constant ELEMENTAL_AFFINITIES = uint256(
    keccak256("elemental_affinities")
);

uint256 constant EXPERTISE_VALUES = uint256(keccak256("expertise_values"));

contract StarterPirateNFTTokenURIHandler is
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
            ITokenTemplateSystem(_getSystem(TOKEN_TEMPLATE_SYSTEM_ID))
                .generateTokenURIWithExtra(
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

        ITokenTemplateSystem tokenTemplateSystem = ITokenTemplateSystem(
            _getSystem(TOKEN_TEMPLATE_SYSTEM_ID)
        );

        ContractInfo storage contractInfo = _contracts[tokenContract];
        uint256[] memory assetIds = this.getAssetTraitIds(tokenContract);

        uint256 numStaticTraits = 6;
        TokenURITrait[] memory extraTraits = new TokenURITrait[](
            numStaticTraits + assetIds.length
        );

        // Note: All of the below try to get the data from the template system so that inherited traits show up

        // External URL
        extraTraits[0] = TokenURITrait({
            name: "external_url",
            value: abi.encode(traitsConsumer.externalURI(tokenId)),
            dataType: TraitDataType.STRING,
            hidden: false,
            isTopLevelProperty: true
        });

        // Name
        extraTraits[1] = TokenURITrait({
            name: "name",
            value: _tokenName(tokenContract, tokenId),
            dataType: TraitDataType.STRING,
            hidden: false,
            isTopLevelProperty: true
        });

        // Image
        extraTraits[2] = TokenURITrait({
            name: "image",
            value: tokenTemplateSystem.hasTrait(
                tokenContract,
                tokenId,
                IMAGE_TRAIT_ID
            )
                ? tokenTemplateSystem.getTraitBytes(
                    tokenContract,
                    tokenId,
                    IMAGE_TRAIT_ID
                )
                : abi.encode(traitsConsumer.imageURI(tokenId)),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: true,
            hidden: false
        });

        // Description
        extraTraits[3] = TokenURITrait({
            name: "description",
            value: _description(tokenContract, tokenId),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: true,
            hidden: false
        });

        // Elemental Affinity string
        extraTraits[4] = TokenURITrait({
            name: "Elemental Affinity",
            dataType: TraitDataType.STRING,
            value: _elementalAffinity(tokenContract, tokenId),
            isTopLevelProperty: false,
            hidden: false
        });

        // Expertise string
        extraTraits[5] = TokenURITrait({
            name: "Expertise",
            dataType: TraitDataType.STRING,
            value: _expertise(tokenContract, tokenId),
            isTopLevelProperty: false,
            hidden: false
        });

        for (uint256 idx = 0; idx < assetIds.length; idx++) {
            Asset storage asset = contractInfo.assets[assetIds[idx]];

            extraTraits[numStaticTraits + idx] = TokenURITrait({
                name: asset.traitName,
                isTopLevelProperty: true,
                dataType: TraitDataType.STRING,
                value: abi.encode(
                    string(abi.encodePacked(asset.uri, tokenId.toString()))
                ),
                hidden: false
            });
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
            abi.encodePacked("Pirate #", tokenId.toString())
        );
        return abi.encode(pirateName);
    }

    /**
     * @dev Handle NFT description field with component and fallback
     */
    function _description(
        address tokenContract,
        uint256 tokenId
    ) internal view returns (bytes memory) {
        DescriptionComponent descriptionComponent = DescriptionComponent(
            _gameRegistry.getComponent(DescriptionComponentId)
        );
        uint256 entity = EntityLibrary.tokenToEntity(tokenContract, tokenId);
        if (descriptionComponent.has(entity)) {
            return descriptionComponent.getBytes(entity);
        }
        string memory description = IGameGlobals(_getSystem(GAME_GLOBALS_ID))
            .getString(STARTER_PIRATE_DESCRIPTION);
        return abi.encode(description);
    }

    /**
     * @dev Handle NFT Elemental Affinity string field
     */
    function _elementalAffinity(
        address tokenContract,
        uint256 tokenId
    ) internal view returns (bytes memory) {
        uint256 affinityId = _traitsProvider().getTraitUint256(
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
