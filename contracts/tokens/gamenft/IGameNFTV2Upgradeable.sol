// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {IHoldingConsumer} from "../../interfaces/IHoldingConsumer.sol";

/**
 * @title Interface for game NFTs that have stats and other properties
 */
interface IGameNFTV2Upgradeable is IHoldingConsumer, IERC721Upgradeable {
    /**
     * @param account Account to check hold time of
     * @param tokenId Id of the token
     * @return The time in seconds a given account has held a token
     */
    function getTimeHeld(
        address account,
        uint256 tokenId
    ) external view returns (uint32);
}
