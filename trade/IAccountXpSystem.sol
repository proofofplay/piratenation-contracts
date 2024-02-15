// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

uint256 constant ID = uint256(keccak256("game.piratenation.accountxpsystem"));

/// @title Interface for the AccountXpSystem that grants Account Xp for completing actions
interface IAccountXpSystem {
    function grantAccountXp(
        uint256 actionEntityId,
        uint256 entityToGrant
    ) external;

    function getAccountXp(
        uint256 accountEntity
    ) external view returns (uint256);

    function getPlayerAccountLevel(
        uint256 accountEntity
    ) external view returns (uint256);

    function convertAccountXpToLevel(
        uint256 accountXp
    ) external view returns (uint256);
}
