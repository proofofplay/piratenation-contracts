// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../../libraries/JSONRenderer.sol";

import {MixinLibrary} from "../../libraries/MixinLibrary.sol";
import {EntityLibrary} from "../../core/EntityLibrary.sol";

import {ITokenURIHandler} from "../ITokenURIHandler.sol";
import {GameRegistryConsumerUpgradeable} from "../../GameRegistryConsumerUpgradeable.sol";
import {TokenURITrait, TraitDataType} from "../../interfaces/ITraitsProvider.sol";

import {MixinComponent, ID as MIXIN_COMPONENT_ID} from "../../generated/components/MixinComponent.sol";
import {NameComponent, ID as NAME_COMPONENT_ID} from "../../generated/components/NameComponent.sol";
import {AchievedAtComponent, ID as ACHIEVED_AT_COMPONENT_ID} from "../../generated/components/AchievedAtComponent.sol";
import {ID as ANIMATION_URL_COMPONENT_ID} from "../../generated/components/AnimationUrlComponent.sol";
import {ID as DESCRIPTION_COMPONENT_ID} from "../../generated/components/DescriptionComponent.sol";
import {ID as IMAGE_URL_COMPONENT_ID} from "../../generated/components/ImageUrlComponent.sol";
import {ID as SOULBOUND_COMPONENT_ID} from "../../generated/components/SoulboundComponent.sol";
import {IComponent} from "../../core/components/IComponent.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.achievementnfttokenurihandler")
);

contract AchievementNFTTokenURIHandler is
    GameRegistryConsumerUpgradeable,
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

        uint256 numStaticTraits = 7;

        TokenURITrait[] memory baseTraits = new TokenURITrait[](
            numStaticTraits
        );

        // top-level properties

        // Name
        baseTraits[0] = TokenURITrait({
            name: "name",
            value: MixinLibrary.getBytesValue(
                entity,
                mixins,
                IComponent(_gameRegistry.getComponent(DESCRIPTION_COMPONENT_ID))
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
                IComponent(_gameRegistry.getComponent(DESCRIPTION_COMPONENT_ID))
            ),
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
            value: MixinLibrary.getBytesValue(
                entity,
                mixins,
                IComponent(
                    _gameRegistry.getComponent(ANIMATION_URL_COMPONENT_ID)
                )
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: true,
            hidden: false
        });

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
            name: "Achieved At",
            value: abi.encode(
                AchievedAtComponent(
                    _gameRegistry.getComponent(ACHIEVED_AT_COMPONENT_ID)
                ).getValue(entity)
            ),
            dataType: TraitDataType.STRING,
            isTopLevelProperty: false,
            hidden: false
        });

        baseTraits[6] = TokenURITrait({
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

        return JSONRenderer.generateTokenURI(baseTraits);
    }
}
