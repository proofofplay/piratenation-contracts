// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "../gameglobals/GameGlobals.sol";

/** @title Game Globals Mock for testing */
contract GameGlobalsMock is GameGlobals {
    bytes4 public constant GAMEGLOBALS_INTERFACEID =
        type(IGameGlobals).interfaceId;
}
