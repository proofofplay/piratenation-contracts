// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.gameitems"));

interface IGameItems is IERC1155 {
    /**
     * Mints a ERC1155 token
     *
     * @param to        Recipient of the token
     * @param id        Id of token to mint
     * @param amount    Quantity of token to mint
     */
    function mint(
        address to,
        uint256 id,
        uint256 amount
    ) external;

    /**
     * Burn a token - any payment / game logic should be handled in the game contract.
     *
     * @param from      Account to burn from
     * @param id        Id of the token to burn
     * @param amount    Quantity to burn
     */
    function burn(
        address from,
        uint256 id,
        uint256 amount
    ) external;

    /**
     * @param id  Id of the type to get data for
     *
     * @return How many of the given token id have been minted
     */
    function minted(uint256 id) external view returns (uint256);
}
