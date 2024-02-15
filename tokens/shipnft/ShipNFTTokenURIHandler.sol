// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ITokenURIHandler} from "../ITokenURIHandler.sol";
import {ITraitsConsumer} from "../../interfaces/ITraitsConsumer.sol";
import {ITraitsProvider, TokenURITrait, TraitDataType} from "../../interfaces/ITraitsProvider.sol";
import {GameRegistryConsumerUpgradeable} from "../../GameRegistryConsumerUpgradeable.sol";
import {ContractTraits} from "../ContractTraits.sol";
import {MANAGER_ROLE, NAME_TRAIT_ID, IMAGE_TRAIT_ID, ANIMATION_URL_TRAIT_ID, DESCRIPTION_TRAIT_ID, CURRENT_HEALTH_TRAIT_ID} from "../../Constants.sol";
import {EntityLibrary} from "../../core/EntityLibrary.sol";
import {IEquippable} from "../../equipment/IEquippable.sol";
import {ID as SHIP_EQUIPMENT_ID, SHIP_CORE_SLOT_TYPE} from "../../equipment/ShipEquipment.sol";
import {ITraitsProvider, ID as TRAITS_PROVIDER_ID} from "../../interfaces/ITraitsProvider.sol";
import {ArrayLibrary} from "../../libraries/ArrayLibrary.sol";
import {ITokenTemplateSystem, ID as TOKEN_TEMPLATE_SYSTEM_ID} from "../../tokens/ITokenTemplateSystem.sol";
import {ImageUrlComponent, ID as IMAGE_URL_COMPONENT_ID} from "../../generated/components/ImageUrlComponent.sol";
import {AnimationUrlComponent, ID as ANIMATION_URL_COMPONENT_ID} from "../../generated/components/AnimationUrlComponent.sol";
import {NameComponent, ID as NAME_COMPONENT_ID} from "../../generated/components/NameComponent.sol";
import {SkinContainerComponent, Layout as SkinContainerComponentLayout, ID as SKIN_CONTAINER_ID} from "../../generated/components/SkinContainerComponent.sol";
import {LevelComponent, ID as LEVEL_COMPONENT_ID} from "../../generated/components/LevelComponent.sol";
import {HealthArrayComponent, Layout as HealthArrayComponentLayout, ID as HEALTH_ARRAY_ID} from "../../generated/components/HealthArrayComponent.sol";

uint256 constant EQUIPMENT_LIMIT = 6;
uint256 constant ID = uint256(
    keccak256("game.piratenation.shipnfttokenurihandler")
);

contract ShipNFTTokenURIHandler is
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

        (
            address templateTokenAddress,
            uint256 templateTokenId
        ) = tokenTemplateSystem.getTemplate(tokenContract, tokenId);

        // Get equipment traits
        TokenURITrait[] memory equipmentTraits = _getEquipmentTraits(
            tokenContract,
            tokenId
        );

        uint256 numStaticTraits = 9 + equipmentTraits.length;
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
                ? abi.encode(
                    string.concat(
                        tokenTemplateSystem.getTraitString(
                            tokenContract,
                            tokenId,
                            NAME_TRAIT_ID
                        ),
                        " (Lv ",
                        _handleLevelTrait(
                            EntityLibrary.tokenToEntity(tokenContract, tokenId)
                        ).toString(),
                        ")"
                    )
                )
                : abi.encode(
                    string.concat(
                        traitsConsumer.tokenName(tokenId),
                        " (Lv ",
                        _handleLevelTrait(
                            EntityLibrary.tokenToEntity(tokenContract, tokenId)
                        ).toString(),
                        ")"
                    )
                ),
            dataType: TraitDataType.STRING,
            hidden: false,
            isTopLevelProperty: true
        });

        // Ship type (name of template), get specifically from template via traitsprovider
        extraTraits[2] = TokenURITrait({
            name: "ship_type",
            value: abi.encode(
                tokenTemplateSystem.hasTrait(
                    templateTokenAddress,
                    templateTokenId,
                    NAME_TRAIT_ID
                )
                    ? ITraitsProvider(_getSystem(TRAITS_PROVIDER_ID))
                        .getTraitString(
                            templateTokenAddress,
                            templateTokenId,
                            NAME_TRAIT_ID
                        )
                    : traitsConsumer.tokenName(tokenId)
            ),
            dataType: TraitDataType.STRING,
            hidden: false,
            isTopLevelProperty: false
        });

        // Image
        extraTraits[3] = TokenURITrait({
            name: "image",
            value: _handleImageTrait(
                tokenTemplateSystem,
                traitsConsumer,
                tokenContract,
                tokenId
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: true,
            hidden: false
        });

        // Description
        extraTraits[4] = TokenURITrait({
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
            isTopLevelProperty: true,
            hidden: false
        });

        // Current Health with formatting
        extraTraits[5] = TokenURITrait({
            name: "Current Health",
            dataType: TraitDataType.UINT,
            value: _handleCurrentHealthTrait(
                EntityLibrary.tokenToEntity(
                    templateTokenAddress,
                    templateTokenId
                ),
                EntityLibrary.tokenToEntity(tokenContract, tokenId)
            ),
            hidden: false,
            isTopLevelProperty: false
        });

        extraTraits[6] = TokenURITrait({
            name: "animation_url",
            dataType: TraitDataType.STRING,
            value: _handleAnimationUrlTrait(
                tokenTemplateSystem,
                tokenContract,
                tokenId
            ),
            hidden: false,
            isTopLevelProperty: true
        });

        extraTraits[7] = TokenURITrait({
            name: "Skin Equipped",
            dataType: TraitDataType.STRING,
            value: _handleSkinEquippedTrait(tokenContract, tokenId),
            hidden: false,
            isTopLevelProperty: false
        });

        extraTraits[8] = TokenURITrait({
            name: "Level",
            dataType: TraitDataType.UINT,
            value: abi.encode(
                _handleLevelTrait(
                    EntityLibrary.tokenToEntity(tokenContract, tokenId)
                )
            ),
            hidden: false,
            isTopLevelProperty: false
        });

        // Loop through equipment traits and add them to the extra traits array
        for (uint256 i = 0; i < equipmentTraits.length; i++) {
            extraTraits[
                i + numStaticTraits - equipmentTraits.length
            ] = equipmentTraits[i];
        }

        return extraTraits;
    }

    /** INTERNAL **/

    /**
     * @dev This override includes the locked and soulbound traits
     * @param tokenId  Token to generate extra traits array for
     * @return Extra traits to include in the tokenURI metadata
     */
    function _getEquipmentTraits(
        address tokenContract,
        uint256 tokenId
    ) internal view returns (TokenURITrait[] memory) {
        // Extend static traits by number of equipped items bounded by EQUIPMENT_LIMIT
        uint256[] memory equippedItems = IEquippable(
            _getSystem(SHIP_EQUIPMENT_ID)
        ).getItems(
                EntityLibrary.tokenToEntity(tokenContract, tokenId),
                SHIP_CORE_SLOT_TYPE
            );

        // Make sure to have an upper bound on number of items to avoid OOG
        uint256 itemLength = equippedItems.length > EQUIPMENT_LIMIT
            ? EQUIPMENT_LIMIT
            : equippedItems.length;

        // Loop through equipped items on trait provider and add them to the extra traits
        uint256 count = 0;
        uint256 traitCount = 0;
        uint256 itemTokenId;
        address itemTokenContract;

        bool[] memory visited = new bool[](itemLength);
        TokenURITrait[] memory extraTraits = new TokenURITrait[](itemLength);
        for (uint256 i = 0; i < itemLength; i++) {
            // Skip if we've already counted this item or if it's 0
            if (visited[i] == true || equippedItems[i] == 0) {
                continue;
            }

            // Iterate through remainder of itemLength and count occurrences
            count = 1;
            for (uint256 j = i + 1; j < itemLength; j++) {
                if (equippedItems[i] == equippedItems[j]) {
                    count++;
                    visited[j] = true;
                }
            }

            // Get the item's token contract and id
            (itemTokenContract, itemTokenId) = EntityLibrary.entityToToken(
                equippedItems[i]
            );

            // Add the item's name to the extra traits
            extraTraits[traitCount] = TokenURITrait({
                name: string.concat(
                    "Has ",
                    ITraitsConsumer(itemTokenContract).tokenName(itemTokenId)
                ),
                value: abi.encode(count),
                dataType: TraitDataType.UINT,
                hidden: false,
                isTopLevelProperty: false
            });
            traitCount++;
        }

        // Resize the extra traits array to the number of traits added
        TokenURITrait[] memory resizedExtraTraits = new TokenURITrait[](
            traitCount
        );
        for (uint256 i = 0; i < traitCount; i++) {
            resizedExtraTraits[i] = extraTraits[i];
        }

        return resizedExtraTraits;
    }

    function _handleImageTrait(
        ITokenTemplateSystem tokenTemplateSystem,
        ITraitsConsumer traitsConsumer,
        address tokenContract,
        uint256 tokenId
    ) internal view returns (bytes memory) {
        // Check if skin is equipped
        SkinContainerComponentLayout
            memory skinContainer = SkinContainerComponent(
                _gameRegistry.getComponent(SKIN_CONTAINER_ID)
            ).getLayoutValue(
                    EntityLibrary.tokenToEntity(tokenContract, tokenId)
                );
        // If no skin is equipped, return regular value
        if (skinContainer.slotEntities.length == 0) {
            return
                tokenTemplateSystem.hasTrait(
                    tokenContract,
                    tokenId,
                    IMAGE_TRAIT_ID
                )
                    ? tokenTemplateSystem.getTraitBytes(
                        tokenContract,
                        tokenId,
                        IMAGE_TRAIT_ID
                    )
                    : abi.encode(traitsConsumer.imageURI(tokenId));
        }
        // If skin is equipped then return skin ipfsUrl
        string memory skin = ImageUrlComponent(
            _gameRegistry.getComponent(IMAGE_URL_COMPONENT_ID)
        ).getValue(skinContainer.skinEntities[0]);
        return abi.encode(skin);
    }

    /**
     * @dev Internal func handles animation_url trait
     * @param tokenTemplateSystem TokenTemplateSystem contract
     * @param tokenContract token contract address
     * @param tokenId token id
     */
    function _handleAnimationUrlTrait(
        ITokenTemplateSystem tokenTemplateSystem,
        address tokenContract,
        uint256 tokenId
    ) internal view returns (bytes memory) {
        // Check if skin is equipped
        SkinContainerComponentLayout
            memory skinContainer = SkinContainerComponent(
                _gameRegistry.getComponent(SKIN_CONTAINER_ID)
            ).getLayoutValue(
                    EntityLibrary.tokenToEntity(tokenContract, tokenId)
                );
        // If no skin is equipped, return regular value
        if (skinContainer.slotEntities.length == 0) {
            return
                tokenTemplateSystem.getTraitBytes(
                    tokenContract,
                    tokenId,
                    ANIMATION_URL_TRAIT_ID
                );
        }
        // If skin is equipped then return animationUrlComponent
        string memory animationUrl = AnimationUrlComponent(
            _gameRegistry.getComponent(ANIMATION_URL_COMPONENT_ID)
        ).getValue(skinContainer.skinEntities[0]);
        return abi.encode(animationUrl);
    }

    /**
     * @dev Internal func handles Skin Equipped metadata trait
     * @param tokenContract token contract address
     * @param tokenId token id
     */
    function _handleSkinEquippedTrait(
        address tokenContract,
        uint256 tokenId
    ) internal view returns (bytes memory) {
        // Check if skin is equipped
        string memory equipped = "None";
        SkinContainerComponentLayout
            memory skinContainer = SkinContainerComponent(
                _gameRegistry.getComponent(SKIN_CONTAINER_ID)
            ).getLayoutValue(
                    EntityLibrary.tokenToEntity(tokenContract, tokenId)
                );
        // If skin is equipped then return entity name from NameComponent
        if (skinContainer.slotEntities.length > 0) {
            equipped = NameComponent(
                _gameRegistry.getComponent(NAME_COMPONENT_ID)
            ).getValue(skinContainer.skinEntities[0]);
        }
        return abi.encode(equipped);
    }

    function _handleCurrentHealthTrait(
        uint256 templateEntityId,
        uint256 tokenEntityId
    ) internal view returns (bytes memory) {
        uint256[] memory healthArray = HealthArrayComponent(
            _gameRegistry.getComponent(HEALTH_ARRAY_ID)
        ).getValue(templateEntityId);
        uint256 shipLevel = LevelComponent(
            _gameRegistry.getComponent(LEVEL_COMPONENT_ID)
        ).getValue(tokenEntityId);
        if (shipLevel == 0) {
            shipLevel = 1;
        }
        uint256 shipHealth;
        if (healthArray.length > 0) {
            shipHealth = healthArray[shipLevel];
        }
        return abi.encode(shipHealth / 1 gwei);
    }

    function _handleLevelTrait(
        uint256 tokenEntityId
    ) internal view returns (uint256) {
        uint256 shipLevel = LevelComponent(
            _gameRegistry.getComponent(LEVEL_COMPONENT_ID)
        ).getValue(tokenEntityId);
        if (shipLevel == 0) {
            shipLevel = 1;
        }
        return shipLevel;
    }
}
