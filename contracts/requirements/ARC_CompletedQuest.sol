// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {IQuestSystem, ID as QUEST_SYSTEM_ID} from "../quest/IQuestSystem.sol";

import "../GameRegistryConsumerUpgradeable.sol";

import "./IAccountRequirementChecker.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.arccompletedquest"));

contract ARC_CompletedQuest is
    IAccountRequirementChecker,
    GameRegistryConsumerUpgradeable
{
    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /** Whether or not the given bytes array is valid */
    function isDataValid(
        bytes memory data
    ) external pure override returns (bool) {
        uint32 _questId = abi.decode(data, (uint32));
        return _questId > 0;
    }

    /**
     * This check requires data to be a serialized (uint32) of a questId.
     * it checks to make sure the user has previously completed the questId at least once
     * @inheritdoc IAccountRequirementChecker
     */
    function meetsRequirement(
        address account,
        bytes memory data
    ) external view override returns (bool) {
        uint32 questId = abi.decode(data, (uint32));
        IQuestSystem questSystem = IQuestSystem(_getSystem(QUEST_SYSTEM_ID));

        (uint32 completions, ) = questSystem.getQuestDataForAccount(
            account,
            questId
        );
        return completions > 0;
    }
}
