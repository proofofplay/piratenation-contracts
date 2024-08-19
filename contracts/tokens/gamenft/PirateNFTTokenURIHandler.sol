// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";

import {ContractTraits} from "../ContractTraits.sol";
import {ITokenURIHandler} from "../ITokenURIHandler.sol";
import {MANAGER_ROLE, ELEMENTAL_AFFINITY_TRAIT_ID, EXPERTISE_TRAIT_ID} from "../../Constants.sol";
import {GameRegistryConsumerUpgradeable} from "../../GameRegistryConsumerUpgradeable.sol";
import {TokenURITrait, TraitDataType} from "../../interfaces/ITraitsProvider.sol";

import "../../libraries/JSONRenderer.sol";
import {MixinLibrary} from "../../libraries/MixinLibrary.sol";
import {EntityLibrary} from "../../core/EntityLibrary.sol";

import {STARTER_PIRATE_DESCRIPTION, ELEMENTAL_AFFINITIES, EXPERTISE_VALUES} from "../starterpiratenft/StarterPirateNFTTokenURIHandler.sol";

import {NameComponent, ID as NameComponentId, Layout as NameComponentLayout} from "../../generated/components/NameComponent.sol";
import {LevelComponent, ID as LEVEL_COMPONENT_ID} from "../../generated/components/LevelComponent.sol";
import {XpComponent, ID as XP_COMPONENT_ID} from "../../generated/components/XpComponent.sol";
import {AffinityComponent, ID as AFFINITY_COMPONENT_ID} from "../../generated/components/AffinityComponent.sol";
import {ExpertiseComponent, ID as EXPERTISE_COMPONENT_ID} from "../../generated/components/ExpertiseComponent.sol";
import {ImageUrlComponent, ID as IMAGE_URL_COMPONENT_ID} from "../../generated/components/ImageUrlComponent.sol";
import {AvatarBaseSkinComponent, ID as AVATAR_BASE_SKIN_COMPONENT_ID} from "../../generated/components/AvatarBaseSkinComponent.sol";
import {AvatarBaseHairComponent, ID as AVATAR_BASE_HAIR_COMPONENT_ID} from "../../generated/components/AvatarBaseHairComponent.sol";
import {AvatarBaseFacialHairComponent, ID as AVATAR_BASE_FACIAL_HAIR_COMPONENT_ID} from "../../generated/components/AvatarBaseFacialHairComponent.sol";
import {AvatarBaseCoatComponent, ID as AVATAR_BASE_COAT_COMPONENT_ID} from "../../generated/components/AvatarBaseCoatComponent.sol";
import {AvatarBaseHeadwearComponent, ID as AVATAR_BASE_HEAD_WEAR_COMPONENT_ID} from "../../generated/components/AvatarBaseHeadwearComponent.sol";
import {AvatarBaseBackgroundComponent, ID as AVATAR_BASE_BACKGROUND_COMPONENT_ID} from "../../generated/components/AvatarBaseBackgroundComponent.sol";
import {AvatarBaseCharacterTypeComponent, ID as AVATAR_BASE_CHARACTER_TYPE_COMPONENT_ID} from "../../generated/components/AvatarBaseCharacterTypeComponent.sol";
import {AvatarBaseEarringComponent, ID as AVATAR_BASE_EARRING_COMPONENT_ID} from "../../generated/components/AvatarBaseEarringComponent.sol";
import {AvatarBaseEyeCoveringComponent, ID as AVATAR_BASE_EYE_COVERING_COMPONENT_ID} from "../../generated/components/AvatarBaseEyeCoveringComponent.sol";
import {AvatarBaseEyeCoveringComponent, ID as AVATAR_BASE_EYE_COVERING_COMPONENT_ID} from "../../generated/components/AvatarBaseEyeCoveringComponent.sol";
import {AvatarBaseEyesComponent, ID as AVATAR_BASE_EYES_COMPONENT_ID} from "../../generated/components/AvatarBaseEyesComponent.sol";
import {AvatarBaseHairColorComponent, ID as AVATAR_BASE_HAIR_COLOR_COMPONENT_ID} from "../../generated/components/AvatarBaseHairColorComponent.sol";
import {AvatarBaseMageGemComponent, ID as AVATAR_BASE_MAGE_GEM_COMPONENT_ID} from "../../generated/components/AvatarBaseMageGemComponent.sol";
import {DiceRollComponent, ID as DICE_ROLL_COMPONENT_ID} from "../../generated/components/DiceRollComponent.sol";
import {StarSignComponent, ID as STAR_SIGN_COMPONENT_ID} from "../../generated/components/StarSignComponent.sol";
import {GenerationComponent, ID as GENERATION_COMPONENT_ID} from "../../generated/components/GenerationComponent.sol";
import {MilestonesClaimedComponent, ID as MILESTONES_CLAIMED_COMPONENT_ID} from "../../generated/components/MilestonesClaimedComponent.sol";
import {StringArrayComponent, ID as STRING_ARRAY_COMPONENT_ID} from "../../generated/components/StringArrayComponent.sol";

import {IComponent} from "../../core/components/IComponent.sol";

import {StringComponent, ID as STRING_COMPONENT_ID} from "../../generated/components/StringComponent.sol";
import {StringArrayComponent, ID as STRING_ARRAY_COMPONENT_ID} from "../../generated/components/StringArrayComponent.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.piratenfttokenurihandler")
);

contract PirateNFTTokenURIHandler is
    GameRegistryConsumerUpgradeable,
    ContractTraits,
    ITokenURIHandler
{
    using Strings for uint256;
    using Strings for address;

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

        uint256 numStaticTraits = 25;

        TokenURITrait[] memory baseTraits = new TokenURITrait[](
            numStaticTraits
        );

        NameComponent nameComponent = NameComponent(
            _gameRegistry.getComponent(NameComponentId)
        );

        // Name
        baseTraits[0] = TokenURITrait({
            name: "name",
            value: _tokenName(tokenContract, tokenId),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: true,
            hidden: false
        });

        // Image
        baseTraits[1] = TokenURITrait({
            name: "image",
            value: abi.encode(
                ImageUrlComponent(
                    _gameRegistry.getComponent(IMAGE_URL_COMPONENT_ID)
                ).getValue(entity)
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
            value: abi.encode(
                nameComponent.getValue(
                    AvatarBaseSkinComponent(
                        _gameRegistry.getComponent(
                            AVATAR_BASE_SKIN_COMPONENT_ID
                        )
                    ).getValue(entity)
                )
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: false,
            hidden: false
        });

        // Hair
        baseTraits[5] = TokenURITrait({
            name: "Hair",
            value: abi.encode(
                nameComponent.getValue(
                    AvatarBaseHairComponent(
                        _gameRegistry.getComponent(
                            AVATAR_BASE_HAIR_COMPONENT_ID
                        )
                    ).getValue(entity)
                )
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: false,
            hidden: false
        });

        // Facial Hair
        baseTraits[6] = TokenURITrait({
            name: "Facial Hair",
            value: abi.encode(
                nameComponent.getValue(
                    AvatarBaseFacialHairComponent(
                        _gameRegistry.getComponent(
                            AVATAR_BASE_FACIAL_HAIR_COMPONENT_ID
                        )
                    ).getValue(entity)
                )
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: false,
            hidden: false
        });

        // Coat
        baseTraits[7] = TokenURITrait({
            name: "Coat",
            value: abi.encode(
                nameComponent.getValue(
                    AvatarBaseCoatComponent(
                        _gameRegistry.getComponent(
                            AVATAR_BASE_COAT_COMPONENT_ID
                        )
                    ).getValue(entity)
                )
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: false,
            hidden: false
        });

        // Character Type
        baseTraits[8] = TokenURITrait({
            name: "Character Type",
            value: abi.encode(
                nameComponent.getValue(
                    AvatarBaseCharacterTypeComponent(
                        _gameRegistry.getComponent(
                            AVATAR_BASE_CHARACTER_TYPE_COMPONENT_ID
                        )
                    ).getValue(entity)
                )
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: false,
            hidden: false
        });

        // Headwear
        baseTraits[9] = TokenURITrait({
            name: "Headwear",
            value: abi.encode(
                nameComponent.getValue(
                    AvatarBaseHeadwearComponent(
                        _gameRegistry.getComponent(
                            AVATAR_BASE_HEAD_WEAR_COMPONENT_ID
                        )
                    ).getValue(entity)
                )
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: false,
            hidden: false
        });

        // Earring
        baseTraits[10] = TokenURITrait({
            name: "Earring",
            value: abi.encode(
                nameComponent.getValue(
                    AvatarBaseEarringComponent(
                        _gameRegistry.getComponent(
                            AVATAR_BASE_EARRING_COMPONENT_ID
                        )
                    ).getValue(entity)
                )
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: false,
            hidden: false
        });

        // Eye Covering
        baseTraits[11] = TokenURITrait({
            name: "Eye Covering",
            value: abi.encode(
                nameComponent.getValue(
                    AvatarBaseEyeCoveringComponent(
                        _gameRegistry.getComponent(
                            AVATAR_BASE_EYE_COVERING_COMPONENT_ID
                        )
                    ).getValue(entity)
                )
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: false,
            hidden: false
        });

        // Eyes
        baseTraits[12] = TokenURITrait({
            name: "Eyes",
            value: abi.encode(
                nameComponent.getValue(
                    AvatarBaseEyesComponent(
                        _gameRegistry.getComponent(
                            AVATAR_BASE_EYES_COMPONENT_ID
                        )
                    ).getValue(entity)
                )
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: false,
            hidden: false
        });

        // Hair Color
        baseTraits[13] = TokenURITrait({
            name: "Hair Color",
            value: abi.encode(
                nameComponent.getValue(
                    AvatarBaseHairColorComponent(
                        _gameRegistry.getComponent(
                            AVATAR_BASE_HAIR_COLOR_COMPONENT_ID
                        )
                    ).getValue(entity)
                )
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: false,
            hidden: false
        });

        // Mage Gem : Return "None" if value is 0
        baseTraits[14] = TokenURITrait({
            name: "Mage Gem",
            value: AvatarBaseMageGemComponent(
                _gameRegistry.getComponent(AVATAR_BASE_MAGE_GEM_COMPONENT_ID)
            ).getValue(entity) == 0
                ? abi.encode("None")
                : abi.encode(
                    nameComponent.getValue(
                        AvatarBaseMageGemComponent(
                            _gameRegistry.getComponent(
                                AVATAR_BASE_MAGE_GEM_COMPONENT_ID
                            )
                        ).getValue(entity)
                    )
                ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: false,
            hidden: false
        });

        // Background
        baseTraits[15] = TokenURITrait({
            name: "Background",
            value: abi.encode(
                nameComponent.getValue(
                    AvatarBaseBackgroundComponent(
                        _gameRegistry.getComponent(
                            AVATAR_BASE_BACKGROUND_COMPONENT_ID
                        )
                    ).getValue(entity)
                )
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: false,
            hidden: false
        });

        // Dice Roll 1
        baseTraits[16] = TokenURITrait({
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
        baseTraits[17] = TokenURITrait({
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
        baseTraits[18] = TokenURITrait({
            name: "Star Sign",
            value: abi.encode(
                nameComponent.getValue(
                    StarSignComponent(
                        _gameRegistry.getComponent(STAR_SIGN_COMPONENT_ID)
                    ).getValue(entity)
                )
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: false,
            hidden: false
        });

        // Generation
        baseTraits[19] = TokenURITrait({
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
        baseTraits[20] = TokenURITrait({
            name: "Elemental Affinity",
            value: _elementalAffinity(entity),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: false,
            hidden: false
        });

        // Expertise
        baseTraits[21] = TokenURITrait({
            name: "Expertise",
            value: _expertise(entity),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: false,
            hidden: false
        });

        // Level
        baseTraits[22] = TokenURITrait({
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
        baseTraits[23] = TokenURITrait({
            name: "XP",
            value: abi.encode(
                XpComponent(_gameRegistry.getComponent(XP_COMPONENT_ID))
                    .getValue(entity)
            ),
            dataType: TraitDataType.UINT,
            isTopLevelProperty: false,
            hidden: false
        });

        // Chests Claimed
        baseTraits[24] = TokenURITrait({
            name: "Chests Claimed",
            value: abi.encode(
                MilestonesClaimedComponent(
                    _gameRegistry.getComponent(MILESTONES_CLAIMED_COMPONENT_ID)
                ).getValue(entity).length
            ),
            dataType: TraitDataType.UINT,
            isTopLevelProperty: false,
            hidden: false
        });

        return JSONRenderer.generateTokenURI(baseTraits);
    }

    /** INTERNAL **/

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
        uint256 entity
    ) internal view returns (bytes memory) {
        uint256 affinityId = AffinityComponent(
            _gameRegistry.getComponent(AFFINITY_COMPONENT_ID)
        ).getValue(entity);
        string[] memory affinitiesArray = StringArrayComponent(
            _gameRegistry.getComponent(STRING_ARRAY_COMPONENT_ID)
        ).getValue(ELEMENTAL_AFFINITIES);
        string memory elementalAffinity = affinitiesArray[affinityId - 1];
        return abi.encode(elementalAffinity);
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
        string memory expertise = expertiseArray[expertiseId - 1];
        return abi.encode(expertise);
    }
}
