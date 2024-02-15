// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

uint256 constant ID = uint256(keccak256("game.piratenation.questsystem"));

/// @title Interface for the QuestSystem that lets players go on quests
interface IQuestSystem {
    /**
     * Whether or not a given quest is available to the given player
     *
     * @param account Account to check if quest is available for
     * @param questId Id of the quest to see is available
     *
     * @return Whether or not the quest is available to the given account
     */
    function isQuestAvailable(address account, uint32 questId)
        external
        view
        returns (bool);

    /**
     * @return completions How many times the quest was completed by the given account
     * @return lastCompletionTime Last completion timestamp for the given quest and account
     */
    function getQuestDataForAccount(address account, uint32 questId)
        external
        view
        returns (uint32 completions, uint32 lastCompletionTime);
}
