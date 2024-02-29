// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @title Interface for a in-game currency, based off of ERC20
 */
interface IGameCurrency is IERC20Upgradeable {
    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}
