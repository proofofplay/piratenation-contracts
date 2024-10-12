// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

uint256 constant ID = uint256(keccak256("game.piratenation.accountxpsystem"));
uint256 constant BASE_ACCOUNT_SKILL_ID = uint256(
    keccak256("game.piratenation.global.base_account_skill_id")
);

/// @title Interface for the AccountXpSystem that grants Account Xp for completing actions
interface IAccountXpSystem {

    /**
     * @dev Grant Account Xp to an entity for a specific skill
     * @param entity Entity to grant xp to
     * @param amount Amount of xp to grant
     * @param skillEntity Entity of the account skill
     */
    function grantAccountSkillXp(
        uint256 entity,
        uint256 amount,
        uint256 skillEntity
    ) external;

    /**
     *  Grant Account Xp from an entity
     * @param accountEntity  EntityId of the account
     * @param entityGranting EntityId of the entity granting the xp
     * @param numSuccesses Number of successes
     * @param numFailures Number of failures
     */
    function grantAccountSkillsXp(
        uint256 accountEntity,
        uint256 entityGranting,
        uint256 numSuccesses,
        uint256 numFailures
    ) external;

    /**
     * @dev Does the account have the required skills from an entity with requirements
     * @param accountEntity EntityId of the account
     * @param entityWithRequirements EntityId of the entity with requirements AccountSkillRequirementsComponent
     */
    function hasRequiredSkills(
        uint256 accountEntity,
        uint256 entityWithRequirements
    ) external view returns (bool);

    /**
     * @dev Get the account xp for an entity for a specific skill
     * @param accountEntity EntityId of the account
     */
    function getAccountSkillXp(
        uint256 accountEntity,
        uint256 skillEntity
    ) external view returns (uint256);

    /**
     * @dev Get the current account level for an entity for specific skill
     * @param accountEntity EntityId of the account
     * @param skillEntity Entity of the account skill
     */
    function getAccountSkillLevel(
        uint256 accountEntity,
        uint256 skillEntity
    ) external view returns (uint256);

    /**
     * @dev Convert account xp to level for a specific skill
     * @param accountXp Account xp to convert
     * @param skillEntity Entity of the account skill
     */
    function convertAccountSkillXpToLevel(
        uint256 accountXp,
        uint256 skillEntity
    ) external view returns (uint256);
}
