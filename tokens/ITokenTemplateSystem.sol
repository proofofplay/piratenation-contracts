// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {TokenURITrait} from "../interfaces/ITraitsProvider.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.tokentemplatesystem")
);

/**
 * @title Interface to access token template system
 */
interface ITokenTemplateSystem {
    /**
     * @return Whether or not a template has been defined yet
     *
     * @param templateId    TemplateId to check
     */
    function exists(uint256 templateId) external view returns (bool);

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
    ) external;

    /**
     * @return Returns the template token for the given token contract/token id, if it exists
     *
     * @param tokenContract Token to get the template for
     * @param tokenId to get the template for
     */
    function getTemplate(
        address tokenContract,
        uint256 tokenId
    ) external view returns (address, uint256);

    /**
     * Generates a token URI for a given token that inherits traits from its templates
     *
     * @param tokenContract     Address of the token contract
     * @param tokenId           Id of the token to generate traits for
     *
     * @return base64-encoded fully-formed tokenURI
     */
    function generateTokenURI(
        address tokenContract,
        uint256 tokenId
    ) external view returns (string memory);

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
    ) external view returns (string memory);

    /**
     * Returns whether or not the given token has a trait recursively
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
    ) external view returns (bool);

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
    ) external view returns (bytes memory);

    /**
     * Retrieves a int256 trait for the given token
     *
     * @param tokenContract   Token contract (ERC721 or ERC1155)
     * @param tokenId         Id of the NFT or token type
     * @param traitId         Id of the trait to retrieve
     *
     * @return The value of the trait if it exists, reverts if the trait has not been set or is of a different type.
     */
    function getTraitInt256(
        address tokenContract,
        uint256 tokenId,
        uint256 traitId
    ) external view returns (int256);

    /**
     * Retrieves a uint256 trait for the given token
     *
     * @param tokenContract   Token contract (ERC721 or ERC1155)
     * @param tokenId         Id of the NFT or token type
     * @param traitId         Id of the trait to retrieve
     *
     * @return The value of the trait if it exists, reverts if the trait has not been set or is of a different type.
     */
    function getTraitUint256(
        address tokenContract,
        uint256 tokenId,
        uint256 traitId
    ) external view returns (uint256);

    /**
     * Retrieves a bool trait for the given token
     *
     * @param tokenContract   Token contract (ERC721 or ERC1155)
     * @param tokenId         Id of the NFT or token type
     * @param traitId         Id of the trait to retrieve
     *
     * @return The value of the trait if it exists, reverts if the trait has not been set or is of a different type.
     */
    function getTraitBool(
        address tokenContract,
        uint256 tokenId,
        uint256 traitId
    ) external view returns (bool);

    /**
     * Retrieves a string trait for the given token
     *
     * @param tokenContract   Token contract (ERC721 or ERC1155)
     * @param tokenId         Id of the NFT or token type
     * @param traitId         Id of the trait to retrieve
     *
     * @return The value of the trait if it exists, reverts if the trait has not been set or is of a different type.
     */
    function getTraitString(
        address tokenContract,
        uint256 tokenId,
        uint256 traitId
    ) external view returns (string memory);
}
