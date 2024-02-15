// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

/**
 * Generic interface to let various systems check to see if a given account meets a requirement
 * Example requirements: Account has a given NFT/item, is a certain level, etc.
 */
interface IAccountRequirementChecker {
    /** Whether or not the given bytes array is valid */
    function isDataValid(bytes memory data) external pure returns (bool);

    /**
     * Whether or not the given account meets the requirement
     *
     * @param account Account to check
     * @param data    ABI encoded parameter data to perform the check
     */
    function meetsRequirement(address account, bytes memory data)
        external
        view
        returns (bool);
}
