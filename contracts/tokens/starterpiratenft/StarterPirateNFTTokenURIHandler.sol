// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";

import "../../libraries/JSONRenderer.sol";
import {MixinLibrary} from "../../libraries/MixinLibrary.sol";
import {EntityLibrary} from "../../core/EntityLibrary.sol";

import {ContractTraits} from "../ContractTraits.sol";
import {ITokenURIHandler} from "../ITokenURIHandler.sol";

import {GameRegistryConsumerUpgradeable} from "../../GameRegistryConsumerUpgradeable.sol";

import {TokenURITrait, TraitDataType} from "../../interfaces/ITraitsProvider.sol";

import {MixinComponent, ID as MIXIN_COMPONENT_ID} from "../../generated/components/MixinComponent.sol";
import {NameComponent, ID as NameComponentId, Layout as NameComponentLayout} from "../../generated/components/NameComponent.sol";
import {LevelComponent, ID as LEVEL_COMPONENT_ID} from "../../generated/components/LevelComponent.sol";
import {XpComponent, ID as XP_COMPONENT_ID} from "../../generated/components/XpComponent.sol";
import {AffinityComponent, ID as AFFINITY_COMPONENT_ID} from "../../generated/components/AffinityComponent.sol";
import {ExpertiseComponent, ID as EXPERTISE_COMPONENT_ID} from "../../generated/components/ExpertiseComponent.sol";
import {ID as IMAGE_URL_COMPONENT_ID} from "../../generated/components/ImageUrlComponent.sol";
import {ID as AVATAR_BASE_SKIN_COMPONENT_ID} from "../../generated/components/AvatarBaseSkinComponent.sol";
import {ID as AVATAR_BASE_HAIR_COMPONENT_ID} from "../../generated/components/AvatarBaseHairComponent.sol";
import {ID as AVATAR_BASE_FACIAL_HAIR_COMPONENT_ID} from "../../generated/components/AvatarBaseFacialHairComponent.sol";
import {ID as AVATAR_BASE_COAT_COMPONENT_ID} from "../../generated/components/AvatarBaseCoatComponent.sol";
import {ID as AVATAR_BASE_BACKGROUND_COMPONENT_ID} from "../../generated/components/AvatarBaseBackgroundComponent.sol";
import {DiceRollComponent, ID as DICE_ROLL_COMPONENT_ID} from "../../generated/components/DiceRollComponent.sol";
import {ID as STAR_SIGN_COMPONENT_ID} from "../../generated/components/StarSignComponent.sol";
import {GenerationComponent, ID as GENERATION_COMPONENT_ID} from "../../generated/components/GenerationComponent.sol";
import {HasSoulComponent, ID as HAS_SOUL_COMPONENT_ID} from "../../generated/components/HasSoulComponent.sol";

import {IComponent} from "../../core/components/IComponent.sol";

import {StringComponent, ID as STRING_COMPONENT_ID} from "../../generated/components/StringComponent.sol";
import {StringArrayComponent, ID as STRING_ARRAY_COMPONENT_ID} from "../../generated/components/StringArrayComponent.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.starterpiratenfttokenurihandler")
);

// Global : Starter Pirate NFT description
uint256 constant STARTER_PIRATE_DESCRIPTION = uint256(
    keccak256("game.piratenation.global.starter_pirate_description")
);

// Global : Elemental Affinities
uint256 constant ELEMENTAL_AFFINITIES = uint256(
    keccak256("game.piratenation.global.elemental_affinities")
);

uint256 constant EXPERTISE_VALUES = uint256(
    keccak256("game.piratenation.global.expertise_values")
);

contract StarterPirateNFTTokenURIHandler is
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

        uint256 numStaticTraits = 18;

        TokenURITrait[] memory baseTraits = new TokenURITrait[](
            numStaticTraits
        );

        // Name
        baseTraits[0] = TokenURITrait({
            name: "name",
            value: abi.encode(
                NameComponent(_gameRegistry.getComponent(NameComponentId))
                    .getValue(entity)
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: true,
            hidden: false
        });

        // Image
        baseTraits[1] = TokenURITrait({
            name: "image",
            value: MixinLibrary.getBytesValue(
                entity,
                mixins,
                IComponent(_gameRegistry.getComponent(IMAGE_URL_COMPONENT_ID))
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: true,
            hidden: false
        });

        // Description
        baseTraits[2] = TokenURITrait({
            name: "description",
            value: abi.encode(
                StringComponent(_gameRegistry.getComponent(STRING_COMPONENT_ID))
                    .getValue(STARTER_PIRATE_DESCRIPTION)
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: true,
            hidden: false
        });

        // External URL
        baseTraits[3] = TokenURITrait({
            name: "external_url",
            value: abi.encode(
                string.concat(
                    "https://piratenation.game/pirate/",
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

        // Skin
        baseTraits[4] = TokenURITrait({
            name: "Skin",
            value: MixinLibrary.getBytesValue(
                entity,
                mixins,
                IComponent(
                    _gameRegistry.getComponent(AVATAR_BASE_SKIN_COMPONENT_ID)
                )
            ),
            dataType: TraitDataType.UINT,
            isTopLevelProperty: false,
            hidden: false
        });

        // Hair
        baseTraits[5] = TokenURITrait({
            name: "Hair",
            value: MixinLibrary.getBytesValue(
                entity,
                mixins,
                IComponent(
                    _gameRegistry.getComponent(AVATAR_BASE_HAIR_COMPONENT_ID)
                )
            ),
            dataType: TraitDataType.UINT,
            isTopLevelProperty: false,
            hidden: false
        });

        // Facial Hair
        baseTraits[6] = TokenURITrait({
            name: "Facial Hair",
            value: MixinLibrary.getBytesValue(
                entity,
                mixins,
                IComponent(
                    _gameRegistry.getComponent(
                        AVATAR_BASE_FACIAL_HAIR_COMPONENT_ID
                    )
                )
            ),
            dataType: TraitDataType.UINT,
            isTopLevelProperty: false,
            hidden: false
        });

        // Coat
        baseTraits[7] = TokenURITrait({
            name: "Coat",
            value: MixinLibrary.getBytesValue(
                entity,
                mixins,
                IComponent(
                    _gameRegistry.getComponent(AVATAR_BASE_COAT_COMPONENT_ID)
                )
            ),
            dataType: TraitDataType.UINT,
            isTopLevelProperty: false,
            hidden: false
        });

        // Background
        baseTraits[8] = TokenURITrait({
            name: "Background",
            value: MixinLibrary.getBytesValue(
                entity,
                mixins,
                IComponent(
                    _gameRegistry.getComponent(
                        AVATAR_BASE_BACKGROUND_COMPONENT_ID
                    )
                )
            ),
            dataType: TraitDataType.UINT,
            isTopLevelProperty: false,
            hidden: false
        });

        // Dice Roll 1
        baseTraits[9] = TokenURITrait({
            name: "Dice Roll 1",
            value: abi.encode(
                DiceRollComponent(
                    _gameRegistry.getComponent(DICE_ROLL_COMPONENT_ID)
                ).getLayoutValue(entity).roll1
            ),
            dataType: TraitDataType.UINT,
            isTopLevelProperty: false,
            hidden: false
        });

        // Dice Roll 2
        baseTraits[10] = TokenURITrait({
            name: "Dice Roll 2",
            value: abi.encode(
                DiceRollComponent(
                    _gameRegistry.getComponent(DICE_ROLL_COMPONENT_ID)
                ).getLayoutValue(entity).roll2
            ),
            dataType: TraitDataType.UINT,
            isTopLevelProperty: false,
            hidden: false
        });

        // Star Sign
        baseTraits[11] = TokenURITrait({
            name: "Star Sign",
            value: MixinLibrary.getBytesValue(
                entity,
                mixins,
                IComponent(_gameRegistry.getComponent(STAR_SIGN_COMPONENT_ID))
            ),
            dataType: TraitDataType.UINT,
            isTopLevelProperty: false,
            hidden: false
        });

        // Generation
        baseTraits[12] = TokenURITrait({
            name: "Generation",
            value: abi.encode(
                GenerationComponent(
                    _gameRegistry.getComponent(GENERATION_COMPONENT_ID)
                ).getValue(entity)
            ),
            dataType: TraitDataType.UINT,
            isTopLevelProperty: false,
            hidden: false
        });

        // Elemental Affinity
        baseTraits[13] = TokenURITrait({
            name: "Elemental Affinity",
            value: _elementalAffinity(entity),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: false,
            hidden: false
        });

        // Expertise
        baseTraits[14] = TokenURITrait({
            name: "Expertise",
            value: _expertise(entity),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: false,
            hidden: false
        });

        // Level
        baseTraits[15] = TokenURITrait({
            name: "Level",
            value: abi.encode(
                LevelComponent(_gameRegistry.getComponent(LEVEL_COMPONENT_ID))
                    .getValue(entity)
            ),
            dataType: TraitDataType.UINT,
            isTopLevelProperty: false,
            hidden: false
        });

        // XP
        baseTraits[16] = TokenURITrait({
            name: "XP",
            value: abi.encode(
                XpComponent(_gameRegistry.getComponent(XP_COMPONENT_ID))
                    .getValue(entity)
            ),
            dataType: TraitDataType.UINT,
            isTopLevelProperty: false,
            hidden: false
        });

        // Has Soul
        baseTraits[17] = TokenURITrait({
            name: "Has Soul",
            value: abi.encode(
                HasSoulComponent(
                    _gameRegistry.getComponent(HAS_SOUL_COMPONENT_ID)
                ).getValue(entity)
            ),
            dataType: TraitDataType.BOOL,
            isTopLevelProperty: false,
            hidden: false
        });

        return JSONRenderer.generateTokenURI(baseTraits);
    }

    /**
     * @dev Handle NFT Elemental Affinity string field
     */
    function _elementalAffinity(
        uint256 entity
    ) internal view returns (bytes memory) {
        uint256 affinityId = AffinityComponent(
            _gameRegistry.getComponent(AFFINITY_COMPONENT_ID)
        ).getValue(entity);
        string[] memory affinitiesArray = StringArrayComponent(
            _gameRegistry.getComponent(STRING_ARRAY_COMPONENT_ID)
        ).getValue(ELEMENTAL_AFFINITIES);
        return abi.encode(affinitiesArray[affinityId - 1]);
    }

    /**
     * @dev Handle NFT Expertise string field
     */
    function _expertise(uint256 entity) internal view returns (bytes memory) {
        uint256 expertiseId = ExpertiseComponent(
            _gameRegistry.getComponent(EXPERTISE_COMPONENT_ID)
        ).getValue(entity);
        string[] memory expertiseArray = StringArrayComponent(
            _gameRegistry.getComponent(STRING_ARRAY_COMPONENT_ID)
        ).getValue(EXPERTISE_VALUES);
        return abi.encode(expertiseArray[expertiseId - 1]);
    }
}
