// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

interface ITokenURIHandler {
    /**
     * Generates the TokenURI for a given token
     *
     * @param operator          Sender requesting the tokenURI
     * @param tokenContract     TokenContract to get URI for
     * @param tokenId           Id of the token to get URI for
     *
     * @return TokenURI for the given token
     */
    function tokenURI(
        address operator,
        address tokenContract,
        uint256 tokenId
    ) external view returns (string memory);
}
