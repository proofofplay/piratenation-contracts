// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

uint256 constant ID = uint256(keccak256("game.piratenation.tradelicensesystem"));

/// @title Interface for grant a trade license
interface ITradeLicenseSystem {
    /**
     * Grants a trade license to the given account
     */
    function grantTradeLicense(
        address account
    ) external;

    /**
     * Checks if the given account has a trade license
     */
    function checkHasTradeLicense(
        address account
    ) external view returns (bool);
}
