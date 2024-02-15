// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ITokenURIHandler} from "../ITokenURIHandler.sol";
import {ITraitsConsumer} from "../../interfaces/ITraitsConsumer.sol";
import {ITraitsProvider, TokenURITrait, TraitDataType, ID as TRAITS_PROVIDER_ID} from "../../interfaces/ITraitsProvider.sol";
import {GameRegistryConsumerUpgradeable} from "../../GameRegistryConsumerUpgradeable.sol";
import {ContractTraits} from "../ContractTraits.sol";
import {NAME_TRAIT_ID, IMAGE_TRAIT_ID, DESCRIPTION_TRAIT_ID} from "../../Constants.sol";
import {ITokenTemplateSystem, ID as TOKEN_TEMPLATE_SYSTEM_ID} from "../../tokens/ITokenTemplateSystem.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.achievementnfttokenurihandler")
);

contract AchievementNFTTokenURIHandler is
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
        ITokenTemplateSystem tokenTemplateSystem = ITokenTemplateSystem(
            _getSystem(TOKEN_TEMPLATE_SYSTEM_ID)
        );

        return
            tokenTemplateSystem.generateTokenURIWithExtra(
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

        uint8 numStaticTraits = 5;

        TokenURITrait[] memory extraTraits = new TokenURITrait[](
            numStaticTraits
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
            value: tokenTemplateSystem.hasTrait(
                tokenContract,
                tokenId,
                NAME_TRAIT_ID
            )
                ? tokenTemplateSystem.getTraitBytes(
                    tokenContract,
                    tokenId,
                    NAME_TRAIT_ID
                )
                : abi.encode(traitsConsumer.tokenName(tokenId)),
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
            hidden: false,
            isTopLevelProperty: true
        });

        // Description
        extraTraits[3] = TokenURITrait({
            name: "description",
            value: tokenTemplateSystem.hasTrait(
                tokenContract,
                tokenId,
                DESCRIPTION_TRAIT_ID
            )
                ? tokenTemplateSystem.getTraitBytes(
                    tokenContract,
                    tokenId,
                    DESCRIPTION_TRAIT_ID
                )
                : abi.encode(traitsConsumer.tokenDescription(tokenId)),
            dataType: TraitDataType.STRING,
            hidden: false,
            isTopLevelProperty: true
        });

        // Achievement (for filtering)
        extraTraits[4] = TokenURITrait({
            name: "Achievement",
            value: tokenTemplateSystem.hasTrait(
                tokenContract,
                tokenId,
                NAME_TRAIT_ID
            )
                ? tokenTemplateSystem.getTraitBytes(
                    tokenContract,
                    tokenId,
                    NAME_TRAIT_ID
                )
                : abi.encode(traitsConsumer.tokenName(tokenId)),
            dataType: TraitDataType.STRING,
            hidden: false,
            isTopLevelProperty: false
        });

        return extraTraits;
    }
}
