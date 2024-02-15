// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import {ITokenURIHandler} from "../ITokenURIHandler.sol";
import {ITraitsConsumer} from "../../interfaces/ITraitsConsumer.sol";
import {ITraitsProvider, TokenURITrait, TraitDataType} from "../../interfaces/ITraitsProvider.sol";
import {IGameItems} from "./IGameItems.sol";
import {GameRegistryConsumerUpgradeable} from "../../GameRegistryConsumerUpgradeable.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.gameitemstokenuritransferhandler")
);

contract GameItemsTokenURIHandler is
    GameRegistryConsumerUpgradeable,
    ITokenURIHandler
{
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
     * @param tokenContract Token contract
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
     * @param tokenContract Address of the token contract
     * @param tokenId  Token to generate extra traits array for
     * @return Extra traits to include in the tokenURI metadata
     */
    function getExtraTraits(
        address tokenContract,
        uint256 tokenId
    ) public view returns (TokenURITrait[] memory) {
        ITraitsConsumer traitsConsumer = ITraitsConsumer(tokenContract);
        TokenURITrait[] memory extraTraits = new TokenURITrait[](4);

        // Name
        extraTraits[0] = TokenURITrait({
            name: "name",
            value: abi.encode(traitsConsumer.tokenName(tokenId)),
            dataType: TraitDataType.STRING,
            hidden: false,
            isTopLevelProperty: true
        });

        // Image
        extraTraits[1] = TokenURITrait({
            name: "image",
            value: abi.encode(traitsConsumer.imageURI(tokenId)),
            dataType: TraitDataType.STRING,
            hidden: false,
            isTopLevelProperty: true
        });

        // Description
        extraTraits[2] = TokenURITrait({
            name: "description",
            value: abi.encode(traitsConsumer.tokenDescription(tokenId)),
            dataType: TraitDataType.STRING,
            hidden: false,
            isTopLevelProperty: true
        });

        // External URL
        extraTraits[3] = TokenURITrait({
            name: "external_url",
            value: abi.encode(traitsConsumer.externalURI(tokenId)),
            dataType: TraitDataType.STRING,
            hidden: false,
            isTopLevelProperty: true
        });

        return extraTraits;
    }
}
