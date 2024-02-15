// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import {IGameNFT} from "../../deprecated/IGameNFT.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.achievementnft"));

/**
 * @title Interface for game NFTs that have stats and other properties
 */
interface IAchievementNFT is IGameNFT {
    /**
     * @param to account to mint to
     * @param id of the token
     */
    function mint(address to, uint256 id) external;
}
