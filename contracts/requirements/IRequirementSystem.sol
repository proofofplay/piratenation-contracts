// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

uint256 constant ID = uint256(keccak256("game.piratenation.requirementsystem"));

/// @title Interface for the RequirementSystem that performs state checks against a user account
interface IRequirementSystem {
    // Requirement that must be met
    struct AccountRequirement {
        // Unique id for the requirement
        uint32 requirementId;
        // ABI encoded parameters to perform the requirement check
        bytes requirementData;
    }

    /**
     * Validates whether or not a given set of requirements are valid
     * Errors if there are any invalid requirements
     * @param requirements Requirements to validate
     */
    function validateAccountRequirements(
        AccountRequirement[] memory requirements
    ) external view;

    /**
     * Performs a account requirement check
     * @param account     Account to check
     * @param requirement Requirement to be checked
     * @return Whether or not the requirement was met
     */
    function performAccountCheck(
        address account,
        AccountRequirement memory requirement
    ) external view returns (bool);

    /**
     * Performs a batch account requirement check
     * @param account     Account to check
     * @param requirements Requirements to be checked
     * @return Whether or not the requirement was met
     */
    function performAccountCheckBatch(
        address account,
        AccountRequirement[] memory requirements
    ) external view returns (bool);
}
