// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "../GameRegistryConsumerUpgradeable.sol";
import {MANAGER_ROLE} from "../Constants.sol";
import "./IRequirementSystem.sol";
import "./IAccountRequirementChecker.sol";

/// @title Implementation contract for RequirementSystem that performs state checks against a user account
contract RequirementSystem is
    IRequirementSystem,
    GameRegistryConsumerUpgradeable
{
    /// @notice Requirement checker contracts, these must be set ahead of time so the game code can perform runtime checks
    mapping(uint32 => IAccountRequirementChecker) _accountRequirementCheckers;

    /** ERRORS **/

    /// @notice Requirement checker not defined
    error MissingRequirementChecker();

    /// @notice Data for requirement is not valid
    error InvalidRequirementData();

    /** SETUP **/

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /** PUBLIC **/

    /**
     * Sets a requirement checker for the system
     *
     * @param requirementId         Id of the requirement
     * @param requirementChecker    Address of the checker contract
     */
    function setAccountRequirementChecker(
        uint32 requirementId,
        address requirementChecker
    ) public onlyRole(MANAGER_ROLE) {
        _accountRequirementCheckers[requirementId] = IAccountRequirementChecker(
            requirementChecker
        );
    }

    /** @return The address for the given account requirement checker id */
    function getAccountRequirementChecker(uint32 requirementId)
        external
        view
        returns (address)
    {
        return address(_accountRequirementCheckers[requirementId]);
    }

    /**
     * Validates whether or not a given set of requirements are valid
     * Errors if there are any invalid requirements
     *
     * @param requirements Requirements to validate
     */
    function validateAccountRequirements(
        AccountRequirement[] memory requirements
    ) external view {
        for (uint8 idx; idx < requirements.length; ++idx) {
            IRequirementSystem.AccountRequirement
                memory requirement = requirements[idx];
            IAccountRequirementChecker checker = _accountRequirementCheckers[
                requirement.requirementId
            ];
            if (address(checker) == address(0)) {
                revert MissingRequirementChecker();
            }

            if (checker.isDataValid(requirement.requirementData) != true) {
                revert InvalidRequirementData();
            }
        }
    }

    /**
     * Performs a requirement check
     * @param account     Account to check
     * @param requirement Requirement to be checked
     * @return Whether or not the requirement was met
     */
    function performAccountCheck(
        address account,
        AccountRequirement memory requirement
    ) external view returns (bool) {
        IAccountRequirementChecker checker = _accountRequirementCheckers[
            requirement.requirementId
        ];
        if (
            address(checker) != address(0) &&
            checker.meetsRequirement(account, requirement.requirementData) ==
            true
        ) {
            return true;
        }

        return false;
    }

    /**
     * Performs a batch requirement check
     * @param account     Account to check
     * @param requirements Requirements to be checked
     * @return Whether or not the requirement was met
     */
    function performAccountCheckBatch(
        address account,
        AccountRequirement[] memory requirements
    ) external view returns (bool) {
        for (uint256 idx = 0; idx < requirements.length; ++idx) {
            IRequirementSystem.AccountRequirement
                memory requirement = requirements[idx];
            IAccountRequirementChecker checker = _accountRequirementCheckers[
                requirement.requirementId
            ];
            if (
                address(checker) == address(0) ||
                checker.meetsRequirement(
                    account,
                    requirement.requirementData
                ) ==
                false
            ) {
                return false;
            }
        }

        return true;
    }
}
