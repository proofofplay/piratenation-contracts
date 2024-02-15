// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {TokenURISystem} from "../TokenURISystem.sol";
import {EntityLibrary} from "../../core/EntityLibrary.sol";
import {ImageUrlComponent, ID as IMAGE_URL_COMPONENT_ID} from "../../generated/components/ImageUrlComponent.sol";
import {NameComponent, ID as NAME_COMPONENT_ID} from "../../generated/components/NameComponent.sol";
import {TokenURITrait, TraitDataType} from "../../interfaces/ITraitsProvider.sol";
import {IGameItems, ID as GAME_ITEMS_ID} from "./IGameItems.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.gameitemstokenurisystem")
);

contract GameItemsTokenURISystem is TokenURISystem {
    /** SETUP **/

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * @inheritdoc TokenURISystem
     */
    function getExtraTraits(
        uint256 entity
    ) internal view override returns (TokenURITrait[] memory extraTraits) {
        (, uint256 tokenId) = EntityLibrary.entityToToken(entity);
        extraTraits = new TokenURITrait[](3);

        // External URL
        extraTraits[0] = TokenURITrait({
            name: "external_url",
            value: abi.encode(
                string.concat(
                    "https://piratenation.game/",
                    Strings.toHexString(_getSystem(GAME_ITEMS_ID)),
                    "/",
                    Strings.toString(tokenId)
                )
            ),
            dataType: TraitDataType.STRING,
            hidden: false,
            isTopLevelProperty: true
        });

        // TODO: This is a duplicate of `name`, see if we can deprecate
        extraTraits[1] = TokenURITrait({
            name: "name_trait",
            value: abi.encode(
                NameComponent(_gameRegistry.getComponent(NAME_COMPONENT_ID))
                    .getLayoutValue(entity)
                    .value
            ),
            dataType: TraitDataType.STRING,
            hidden: false,
            isTopLevelProperty: true
        });

        // TODO: This is a duplciate of `image`, see if we can deprecate
        extraTraits[2] = TokenURITrait({
            name: "image_trait",
            value: abi.encode(
                ImageUrlComponent(
                    _gameRegistry.getComponent(IMAGE_URL_COMPONENT_ID)
                ).getLayoutValue(entity).value
            ),
            dataType: TraitDataType.STRING,
            hidden: false,
            isTopLevelProperty: true
        });

        return extraTraits;
    }
}
