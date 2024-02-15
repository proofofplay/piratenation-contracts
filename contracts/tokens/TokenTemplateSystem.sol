// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {TEMPLATE_ID_TRAIT_ID, GAME_LOGIC_CONTRACT_ROLE, MANAGER_ROLE} from "../Constants.sol";
import "../core/EntityLibrary.sol";

import "../libraries/JSONRenderer.sol";
import {TraitMetadata} from "../interfaces/ITraitsProvider.sol";
import {ITokenTemplateSystem, ID} from "./ITokenTemplateSystem.sol";
import "../GameRegistryConsumerUpgradeable.sol";

/**
 * Contract that describes templates used for minting other tokens
 */
contract TokenTemplateSystem is
    GameRegistryConsumerUpgradeable,
    ITokenTemplateSystem
{
    /// @notice Templates that have been initialized
    mapping(uint256 => bool) public initializedEntities;

    /** EVENTS **/
    event EntityCreated(uint256 indexed entityId);

    /** ERRORS */
    error MissingTrait(address tokenContract, uint256 tokenId, uint256 traitId);

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
     * @return Whether or not a template has been defined yet
     */
    function exists(uint256 templateId) public view returns (bool) {
        return
            _traitsProvider().getTraitIds(address(this), templateId).length > 0;
    }

    /**
     * Generates a token URI for a given token without extra template traits
     *
     * @param tokenContract     Address of the token contract
     * @param tokenId           Id of the token to generate traits for
     *
     * @return base64-encoded fully-formed tokenURI
     */
    function generateTokenURI(
        address tokenContract,
        uint256 tokenId
    ) public view returns (string memory) {
        return
            _generateTokenURI(tokenContract, tokenId, new TokenURITrait[](0));
    }

    /**
     * Generates a token URI for a given token that inherits traits from its templates
     *
     * @param tokenContract     Address of the token contract
     * @param tokenId           Id of the token to generate traits for
     * @param extraTraits       Dyanmically generated traits to add on to the generated url
     *
     * @return base64-encoded fully-formed tokenURI
     */
    function generateTokenURIWithExtra(
        address tokenContract,
        uint256 tokenId,
        TokenURITrait[] memory extraTraits
    ) public view returns (string memory) {
        return _generateTokenURI(tokenContract, tokenId, extraTraits);
    }

    /**
     * @return Recursively returns all trait ids for a given token and its parent templates
     */
    function getTraitIds(
        address tokenContract,
        uint256 tokenId
    ) external view returns (uint256[] memory) {
        return _getTraitIds(_traitsProvider(), tokenContract, tokenId);
    }

    /**
     * Initializes an entity
     *
     * @param entityId Id of the entity to initialize
     */
    function createEntity(uint256 entityId) external onlyRole(MANAGER_ROLE) {
        if (initializedEntities[entityId] == false) {
            emit EntityCreated(entityId);
            initializedEntities[entityId] = true;
        }
    }

    /**
     * Sets a template for a given token
     *
     * @param tokenContract Token contract to set template for
     * @param tokenId       Token id to set template for
     * @param templateId    Id of the template to set
     */
    function setTemplate(
        address tokenContract,
        uint256 tokenId,
        uint256 templateId
    ) external onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _traitsProvider().setTraitUint256(
            tokenContract,
            tokenId,
            TEMPLATE_ID_TRAIT_ID,
            EntityLibrary.tokenToEntity(address(this), templateId)
        );
    }

    /**
     * Returns whether or not the given token has a trait (also checks the template)
     *
     * @param tokenContract  Address of the token's contract
     * @param tokenId        NFT tokenId or ERC1155 token type id
     * @param traitId        Id of the trait to retrieve
     *
     * @return Whether or not the token has the trait
     */
    function hasTrait(
        address tokenContract,
        uint256 tokenId,
        uint256 traitId
    ) external view returns (bool) {
        ITraitsProvider traitsProvider = _traitsProvider();

        return _hasTrait(traitsProvider, tokenContract, tokenId, traitId);
    }

    /**
     * @return Returns the template token for the given token contract/token id, if it exists
     */
    function getTemplate(
        address tokenContract,
        uint256 tokenId
    ) external view returns (address, uint256) {
        return _getTemplate(_traitsProvider(), tokenContract, tokenId);
    }

    /**
     * Returns the trait data for a given token and checks the templates
     *
     * @param tokenContract  Address of the token's contract
     * @param tokenId        NFT tokenId or ERC1155 token type id
     * @param traitId        Id of the trait to retrieve
     *
     * @return Trait value as abi-encoded bytes
     */
    function getTraitBytes(
        address tokenContract,
        uint256 tokenId,
        uint256 traitId
    ) external view returns (bytes memory) {
        ITraitsProvider traitsProvider = _traitsProvider();

        return _getTraitBytes(traitsProvider, tokenContract, tokenId, traitId);
    }

    /**
     * Returns the trait data for a given token
     *
     * @param tokenContract  Address of the token's contract
     * @param tokenId        NFT tokenId or ERC1155 token type id
     * @param traitId        Id of the trait to retrieve
     *
     * @return Trait value as a int256
     */
    function getTraitInt256(
        address tokenContract,
        uint256 tokenId,
        uint256 traitId
    ) external view override returns (int256) {
        ITraitsProvider traitsProvider = _traitsProvider();

        return
            abi.decode(
                _getTraitBytes(traitsProvider, tokenContract, tokenId, traitId),
                (int256)
            );
    }

    /**
     * Returns the trait data for a given token
     *
     * @param tokenContract  Address of the token's contract
     * @param tokenId        NFT tokenId or ERC1155 token type id
     * @param traitId        Id of the trait to retrieve
     *
     * @return Trait value as a uint256
     */
    function getTraitUint256(
        address tokenContract,
        uint256 tokenId,
        uint256 traitId
    ) external view override returns (uint256) {
        ITraitsProvider traitsProvider = _traitsProvider();

        return
            abi.decode(
                _getTraitBytes(traitsProvider, tokenContract, tokenId, traitId),
                (uint256)
            );
    }

    /**
     * Returns the trait data for a given token
     *
     * @param tokenContract  Address of the token's contract
     * @param tokenId        NFT tokenId or ERC1155 token type id
     * @param traitId        Id of the trait to retrieve
     *
     * @return Trait value as a bool
     */
    function getTraitBool(
        address tokenContract,
        uint256 tokenId,
        uint256 traitId
    ) external view override returns (bool) {
        ITraitsProvider traitsProvider = _traitsProvider();
        return
            abi.decode(
                _getTraitBytes(traitsProvider, tokenContract, tokenId, traitId),
                (bool)
            );
    }

    /**
     * Returns the trait data for a given token
     *
     * @param tokenContract  Address of the token's contract
     * @param tokenId        NFT tokenId or ERC1155 token type id
     * @param traitId        Id of the trait to retrieve
     *
     * @return Trait value as a string
     */
    function getTraitString(
        address tokenContract,
        uint256 tokenId,
        uint256 traitId
    ) external view override returns (string memory) {
        ITraitsProvider traitsProvider = _traitsProvider();

        return
            abi.decode(
                _getTraitBytes(traitsProvider, tokenContract, tokenId, traitId),
                (string)
            );
    }

    /** INTERNAL **/

    function _getTemplate(
        ITraitsProvider traitsProvider,
        address tokenContract,
        uint256 tokenId
    ) internal view returns (address, uint256) {
        if (
            traitsProvider.hasTrait(
                tokenContract,
                tokenId,
                TEMPLATE_ID_TRAIT_ID
            )
        ) {
            uint256 templateId = traitsProvider.getTraitUint256(
                tokenContract,
                tokenId,
                TEMPLATE_ID_TRAIT_ID
            );
            return EntityLibrary.entityToToken(templateId);
        }

        return (address(0), 0);
    }

    function _getTraitIds(
        ITraitsProvider traitsProvider,
        address tokenContract,
        uint256 tokenId
    ) internal view returns (uint256[] memory) {
        (address templateTokenContract, uint256 templateTokenId) = _getTemplate(
            traitsProvider,
            tokenContract,
            tokenId
        );

        if (templateTokenContract != address(0) && templateTokenId > 0) {
            uint256[] memory templateTraitIds = _getTraitIds(
                traitsProvider,
                templateTokenContract,
                templateTokenId
            );

            uint256[] memory traitIds = traitsProvider.getTraitIds(
                tokenContract,
                tokenId
            );

            // Fetch and process dynamic traits for this token
            uint256[] memory allTraits = new uint256[](
                traitIds.length + templateTraitIds.length
            );

            // Template traits first
            for (uint256 idx; idx < templateTraitIds.length; ++idx) {
                allTraits[idx] = templateTraitIds[idx];
            }

            // Append the token traits onto the allTraits array
            for (uint256 idx; idx < traitIds.length; ++idx) {
                allTraits[templateTraitIds.length + idx] = traitIds[idx];
            }

            return allTraits;
        } else {
            return traitsProvider.getTraitIds(tokenContract, tokenId);
        }
    }

    function _getTraitBytes(
        ITraitsProvider traitsProvider,
        address tokenContract,
        uint256 tokenId,
        uint256 traitId
    ) internal view returns (bytes memory) {
        if (traitsProvider.hasTrait(tokenContract, tokenId, traitId)) {
            return
                traitsProvider.getTraitBytes(tokenContract, tokenId, traitId);
        } else {
            (
                address templateTokenContract,
                uint256 templateTokenId
            ) = _getTemplate(traitsProvider, tokenContract, tokenId);

            if (templateTokenContract != address(0) && templateTokenId > 0) {
                return
                    _getTraitBytes(
                        traitsProvider,
                        templateTokenContract,
                        templateTokenId,
                        traitId
                    );
            }

            revert MissingTrait(tokenContract, tokenId, traitId);
        }
    }

    function _generateTokenURI(
        address tokenContract,
        uint256 tokenId,
        TokenURITrait[] memory extraTraits
    ) internal view returns (string memory) {
        ITraitsProvider traitsProvider = _traitsProvider();

        // Gather all dynamic trait ids
        uint256[] memory traitIds = this.getTraitIds(tokenContract, tokenId);

        // Fetch and process dynamic traits for this token
        TokenURITrait[] memory allTraits = new TokenURITrait[](
            traitIds.length + extraTraits.length
        );

        for (uint256 idx; idx < traitIds.length; ++idx) {
            uint256 traitId = traitIds[idx];
            TraitMetadata memory traitMetadata = traitsProvider
                .getTraitMetadata(traitId);

            allTraits[idx].name = traitMetadata.name;
            allTraits[idx].dataType = traitMetadata.dataType;
            allTraits[idx].hidden = traitMetadata.hidden;
            allTraits[idx].isTopLevelProperty = traitMetadata
                .isTopLevelProperty;
            allTraits[idx].value = _getTraitBytes(
                traitsProvider,
                tokenContract,
                tokenId,
                traitId
            );
        }

        // Append the extra traits onto the allTraits array
        for (uint256 idx; idx < extraTraits.length; ++idx) {
            allTraits[traitIds.length + idx] = extraTraits[idx];
        }

        return JSONRenderer.generateTokenURI(allTraits);
    }

    function _hasTrait(
        ITraitsProvider traitsProvider,
        address tokenContract,
        uint256 tokenId,
        uint256 traitId
    ) internal view returns (bool) {
        if (traitsProvider.hasTrait(tokenContract, tokenId, traitId)) {
            return true;
        } else {
            (
                address templateTokenContract,
                uint256 templateTokenId
            ) = _getTemplate(traitsProvider, tokenContract, tokenId);

            if (templateTokenContract != address(0) && templateTokenId > 0) {
                return
                    _hasTrait(
                        traitsProvider,
                        templateTokenContract,
                        templateTokenId,
                        traitId
                    );
            }

            return false;
        }
    }
}
