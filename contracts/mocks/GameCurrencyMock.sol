// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import {ERC20Upgradeable, ContextUpgradeable, IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../tokens/IGameCurrency.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {MINTER_ROLE} from "../Constants.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.gamecurrencymock"));

contract GameCurrencyMock is
    IGameCurrency,
    GameRegistryConsumerUpgradeable,
    ERC20Upgradeable
{
    uint256 someState;

    /**
     * Initializer function for upgradeable contract
     */
    function initialize(
        string memory name,
        string memory symbol,
        address gameRegistryAddress
    ) public initializer {
        GameRegistryConsumerUpgradeable.__GameRegistryConsumer_init(
            gameRegistryAddress,
            ID
        );
        ERC20Upgradeable.__ERC20_init(name, symbol);
    }

    function mint(
        address to,
        uint256 amount
    ) external override onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {}

    /** INTERNAL */

    /**
     * Message sender override to get Context to work with meta transactions
     *
     */
    function _msgSender()
        internal
        view
        override(ContextUpgradeable, GameRegistryConsumerUpgradeable)
        returns (address)
    {
        return GameRegistryConsumerUpgradeable._msgSender();
    }

    /**
     * Message data override to get Context to work with meta transactions
     */
    function _msgData()
        internal
        view
        override(ContextUpgradeable, GameRegistryConsumerUpgradeable)
        returns (bytes calldata)
    {
        return GameRegistryConsumerUpgradeable._msgData();
    }
}
