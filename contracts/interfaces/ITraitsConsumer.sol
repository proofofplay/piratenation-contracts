// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {ITraitsProvider} from "./ITraitsProvider.sol";

/** @title Consumer of traits, exposes functions to get traits for this contract */
interface ITraitsConsumer {
    /** @return Token name for the given tokenId */
    function tokenName(uint256 tokenId) external view returns (string memory);

    /** @return Token name for the given tokenId */
    function tokenDescription(uint256 tokenId)
        external
        view
        returns (string memory);

    /** @return Image URI for the given tokenId */
    function imageURI(uint256 tokenId) external view returns (string memory);

    /** @return External URI for the given tokenId */
    function externalURI(uint256 tokenId) external view returns (string memory);
}
