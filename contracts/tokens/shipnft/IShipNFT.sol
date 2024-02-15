// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {IGameNFT} from "../../deprecated/IGameNFT.sol";

/**
 * @title Interface for game NFTs that have stats and other properties
 */
interface IShipNFT is IGameNFT {
    /**
     * Mint a token
     *
     * @param to account to mint to
     * @param id of the token
     */
    function mint(address to, uint256 id) external;

    /**
     * Burn a token - any payment / game logic should be handled in the game contract.
     *
     * @param id        Id of the token to burn
     */
    function burn(uint256 id) external;
}
