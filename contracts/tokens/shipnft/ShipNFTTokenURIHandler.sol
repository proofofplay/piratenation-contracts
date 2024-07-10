// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";

import "../../libraries/JSONRenderer.sol";
import {MixinLibrary} from "../../libraries/MixinLibrary.sol";
import {EntityLibrary} from "../../core/EntityLibrary.sol";

import {ITokenURIHandler} from "../ITokenURIHandler.sol";
import {ITraitsConsumer} from "../../interfaces/ITraitsConsumer.sol";
import {TokenURITrait, TraitDataType} from "../../interfaces/ITraitsProvider.sol";
import {GameRegistryConsumerUpgradeable} from "../../GameRegistryConsumerUpgradeable.sol";
import {ContractTraits} from "../ContractTraits.sol";

import {SkinContainerComponent, Layout as SkinContainerComponentLayout, ID as SKIN_CONTAINER_ID} from "../../generated/components/SkinContainerComponent.sol";
import {LevelComponent, ID as LEVEL_COMPONENT_ID} from "../../generated/components/LevelComponent.sol";
import {HealthArrayComponent, Layout as HealthArrayComponentLayout, ID as HEALTH_ARRAY_ID} from "../../generated/components/HealthArrayComponent.sol";
import {ItemsEquippedComponent, ID as ITEMS_EQUIPPED_COMPONENT_ID} from "../../generated/components/ItemsEquippedComponent.sol";
import {MixinComponent, ID as MIXIN_COMPONENT_ID} from "../../generated/components/MixinComponent.sol";
import {NameComponent, ID as NAME_COMPONENT_ID} from "../../generated/components/NameComponent.sol";
import {AnimationUrlComponent, Layout as AnimationUrlComponentLayout, ID as ANIMATION_URL_COMPONENT_ID} from "../../generated/components/AnimationUrlComponent.sol";
import {DescriptionComponent, Layout as DescriptionComponentLayout, ID as DESCRIPTION_COMPONENT_ID} from "../../generated/components/DescriptionComponent.sol";
import {ImageUrlComponent, Layout as ImageUrlComponentLayout, ID as IMAGE_URL_COMPONENT_ID} from "../../generated/components/ImageUrlComponent.sol";
import {ItemSlotsComponent, Layout as ItemSlotsComponentLayout, ID as ITEM_SLOTS_COMPONENT_ID} from "../../generated/components/ItemSlotsComponent.sol";
import {ModelUrlComponent, Layout as ModelUrlComponentLayout, ID as MODEL_URL_COMPONENT_ID} from "../../generated/components/ModelUrlComponent.sol";
import {ID as SOULBOUND_COMPONENT_ID} from "../../generated/components/SoulboundComponent.sol";

import {IComponent} from "../../core/components/IComponent.sol";

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

    /** ERRORS **/

    /// @notice No mixin found
    error NoMixinFound(uint256 entityId);

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
        uint256 entity = EntityLibrary.tokenToEntity(tokenContract, tokenId);
        uint256[] memory mixins = MixinComponent(
            _gameRegistry.getComponent(MIXIN_COMPONENT_ID)
        ).getValue(entity);
        if (mixins.length == 0) {
            revert NoMixinFound(entity);
        }
        uint256 mixinEntity = mixins[0];

        // Get equipment traits
        TokenURITrait[] memory equipmentTraits = _getEquipmentTraits(
            tokenContract,
            tokenId
        );

        uint256 numStaticTraits = 11 + equipmentTraits.length;

        TokenURITrait[] memory baseTraits = new TokenURITrait[](
            numStaticTraits
        );

        // top-level properties

        // Name
        baseTraits[0] = TokenURITrait({
            name: "name",
            value: abi.encode(
                string.concat(
                    NameComponent(_gameRegistry.getComponent(NAME_COMPONENT_ID))
                        .getValue(mixinEntity),
                    " (Lv ",
                    _handleLevelTrait(entity).toString(),
                    ")"
                )
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: true,
            hidden: false
        });

        // Image
        baseTraits[1] = TokenURITrait({
            name: "image",
            value: _handleImageTrait(entity, mixinEntity),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: true,
            hidden: false
        });

        // Description
        baseTraits[2] = TokenURITrait({
            name: "description",
            value: MixinLibrary.getBytesValue(
                entity,
                mixins,
                IComponent(_gameRegistry.getComponent(DESCRIPTION_COMPONENT_ID))
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: true,
            hidden: false
        });

        // Animation URL
        baseTraits[3] = TokenURITrait({
            name: "animation_url",
            value: _handleAnimationUrlTrait(entity, mixinEntity),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: true,
            hidden: false
        });

        // External URL
        baseTraits[4] = TokenURITrait({
            name: "external_url",
            value: abi.encode(
                string.concat(
                    "https://piratenation.game/nft/",
                    Strings.toHexString(tokenContract),
                    "/",
                    tokenId.toString()
                )
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: true,
            hidden: false
        });

        // non-top-level properties (attributes)

        baseTraits[5] = TokenURITrait({
            name: "Item Slots",
            value: MixinLibrary.getBytesValue(
                entity,
                mixins,
                IComponent(_gameRegistry.getComponent(ITEM_SLOTS_COMPONENT_ID))
            ),
            dataType: TraitDataType.UINT,
            isTopLevelProperty: false,
            hidden: false
        });

        baseTraits[6] = TokenURITrait({
            name: "Ship Type",
            value: MixinLibrary.getBytesValue(
                entity,
                mixins,
                IComponent(_gameRegistry.getComponent(NAME_COMPONENT_ID))
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: false,
            hidden: false
        });

        baseTraits[7] = TokenURITrait({
            name: "Current Health",
            value: _handleCurrentHealthTrait(mixinEntity, entity),
            dataType: TraitDataType.UINT,
            isTopLevelProperty: false,
            hidden: false
        });

        baseTraits[8] = TokenURITrait({
            name: "Skin Equipped",
            value: _handleSkinEquippedTrait(entity),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: false,
            hidden: false
        });

        baseTraits[9] = TokenURITrait({
            name: "Level",
            value: abi.encode(_handleLevelTrait(entity)),
            dataType: TraitDataType.UINT,
            isTopLevelProperty: false,
            hidden: false
        });

        baseTraits[10] = TokenURITrait({
            name: "Soulbound",
            value: MixinLibrary.getBytesValue(
                entity,
                mixins,
                IComponent(_gameRegistry.getComponent(SOULBOUND_COMPONENT_ID))
            ),
            dataType: TraitDataType.BOOL,
            isTopLevelProperty: false,
            hidden: false
        });

        // Loop through equipment traits and add them to the extra traits array
        for (uint256 i = 0; i < equipmentTraits.length; i++) {
            baseTraits[
                i + numStaticTraits - equipmentTraits.length
            ] = equipmentTraits[i];
        }

        return JSONRenderer.generateTokenURI(baseTraits);
    }

    /** INTERNAL **/

    /**
     * @dev Handle equipped items
     */
    function _getEquipmentTraits(
        address tokenContract,
        uint256 tokenId
    ) internal view returns (TokenURITrait[] memory) {
        // Extend static traits by number of equipped items bounded by EQUIPMENT_LIMIT
        uint256[] memory equippedItems = ItemsEquippedComponent(
            _gameRegistry.getComponent(ITEMS_EQUIPPED_COMPONENT_ID)
        ).getValue(EntityLibrary.tokenToEntity(tokenContract, tokenId));

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

    /**
     * @dev Handle image trait, if skin is equipped return skin image
     */
    function _handleImageTrait(
        uint256 entity,
        uint256 mixinEntity
    ) internal view returns (bytes memory) {
        // Check if skin is equipped
        SkinContainerComponentLayout
            memory skinContainer = SkinContainerComponent(
                _gameRegistry.getComponent(SKIN_CONTAINER_ID)
            ).getLayoutValue(entity);
        // If no skin is equipped, return regular value
        if (skinContainer.slotEntities.length == 0) {
            return
                abi.encode(
                    ImageUrlComponent(
                        _gameRegistry.getComponent(IMAGE_URL_COMPONENT_ID)
                    ).getValue(mixinEntity)
                );
        }
        // If skin is equipped then return skin ipfsUrl
        string memory skin = ImageUrlComponent(
            _gameRegistry.getComponent(IMAGE_URL_COMPONENT_ID)
        ).getValue(skinContainer.skinEntities[0]);
        return abi.encode(skin);
    }

    /**
     * @dev Handle animationUrl trait, if skin is equipped return skin animationUrl
     */
    function _handleAnimationUrlTrait(
        uint256 entity,
        uint256 mixinEntity
    ) internal view returns (bytes memory) {
        // Check if skin is equipped
        SkinContainerComponentLayout
            memory skinContainer = SkinContainerComponent(
                _gameRegistry.getComponent(SKIN_CONTAINER_ID)
            ).getLayoutValue(entity);
        // If no skin is equipped, return regular value
        if (skinContainer.slotEntities.length == 0) {
            return
                abi.encode(
                    AnimationUrlComponent(
                        _gameRegistry.getComponent(ANIMATION_URL_COMPONENT_ID)
                    ).getValue(mixinEntity)
                );
        }
        // If skin is equipped then return animationUrlComponent
        string memory animationUrl = AnimationUrlComponent(
            _gameRegistry.getComponent(ANIMATION_URL_COMPONENT_ID)
        ).getValue(skinContainer.skinEntities[0]);
        return abi.encode(animationUrl);
    }

    /**
     * @dev Handle skin equipped trait
     */
    function _handleSkinEquippedTrait(
        uint256 entity
    ) internal view returns (bytes memory) {
        // Check if skin is equipped
        string memory equipped = "None";
        SkinContainerComponentLayout
            memory skinContainer = SkinContainerComponent(
                _gameRegistry.getComponent(SKIN_CONTAINER_ID)
            ).getLayoutValue(entity);
        // If skin is equipped then return entity name from NameComponent
        if (skinContainer.slotEntities.length > 0) {
            equipped = NameComponent(
                _gameRegistry.getComponent(NAME_COMPONENT_ID)
            ).getValue(skinContainer.skinEntities[0]);
        }
        return abi.encode(equipped);
    }

    /**
     * @dev Handle current health trait
     */
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

    /**
     * @dev Handle level trait
     */
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
