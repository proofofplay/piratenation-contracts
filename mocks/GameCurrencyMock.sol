// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../tokens/IGameCurrency.sol";
import "../GameRegistryConsumer.sol";
import {MINTER_ROLE} from "../Constants.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.gamecurrencymock"));

contract GameCurrencyMock is ERC20, IGameCurrency, GameRegistryConsumer {
    uint256 someState;

    constructor(
        string memory name,
        string memory symbol,
        address gameRegistryAddress
    ) ERC20(name, symbol) GameRegistryConsumer(gameRegistryAddress, ID) {}

    function mint(address to, uint256 amount)
        external
        override
        onlyRole(MINTER_ROLE)
    {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {}

    /**
     * Message sender override to get Context to work with meta transactions
     *
     */
    function _msgSender()
        internal
        view
        override(Context, GameRegistryConsumer)
        returns (address)
    {
        return GameRegistryConsumer._msgSender();
    }

    /**
     * Message data override to get Context to work with meta transactions
     *
     */
    function _msgData()
        internal
        view
        override(Context, GameRegistryConsumer)
        returns (bytes calldata)
    {
        return GameRegistryConsumer._msgData();
    }
}
