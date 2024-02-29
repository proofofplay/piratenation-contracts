// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {GameRegistryLibrary} from "../libraries/GameRegistryLibrary.sol";
import {GameHelperLibrary} from "../libraries/GameHelperLibrary.sol";
import "../libraries/TraitsLibrary.sol";
import "../libraries/RandomLibrary.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";

import {RANDOMIZER_ROLE, MANAGER_ROLE, GAME_CURRENCY_CONTRACT_ROLE, PERCENTAGE_RANGE, GAME_NFT_CONTRACT_ROLE, IS_PIRATE_TRAIT_ID} from "../Constants.sol";

import {IGameItems} from "../tokens/gameitems/IGameItems.sol";
import {IGameCurrency} from "../tokens/IGameCurrency.sol";
import {ITraitsProvider} from "../interfaces/ITraitsProvider.sol";
import {ILevelSystem, ID as LEVEL_SYSTEM_ID} from "../level/ILevelSystem.sol";
import {ILootSystem} from "../loot/ILootSystem.sol";
import {IRequirementSystem, ID as REQUIREMENT_SYSTEM_ID} from "../requirements/IRequirementSystem.sol";
import {IEnergySystemV3, ID as ENERGY_SYSTEM_ID} from "../energy/IEnergySystem.sol";
import {IQuestSystem, ID} from "./IQuestSystem.sol";
import {ICooldownSystem, ID as COOLDOWN_SYSTEM_ID} from "../cooldown/ICooldownSystem.sol";
import {ID as PIRATE_NFT_ID} from "../tokens/PirateNFTL2.sol";

import "../GameRegistryConsumerUpgradeable.sol";

contract QuestSystem is IQuestSystem, GameRegistryConsumerUpgradeable {
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;

    struct QuestInput {
        // Pointer to a token (if ERC20, ERC721, or ERC1155 input type)
        GameRegistryLibrary.TokenPointer tokenPointer;
        // Traits to check against
        TraitCheck[] traitChecks;
        // Amount of energy used by this input
        uint256 energyRequired;
        // Whether or not this input is required
        bool required;
        // Whether or not the input is burned
        bool consumable;
        // Chance of losing the consumable item on a failure, 0 - 10000 (0 = 0%, 10000 = 100%)
        uint32 failureBurnProbability;
        // Chance of burning the consumable item on success, 0 - 10000 (0 = 0%, 10000 = 100%)
        uint32 successBurnProbability;
        // Amount of XP gained by this input (ERC721-types only, 0 - 10000 (0 = 0%, 10000 = 100%))
        uint32 xpEarnedPercent;
    }

    // Full definition for a quest in the game
    struct QuestDefinition {
        // Whether or not the quest is enabled
        bool enabled;
        // Requirements that must be met before quest can be started
        IRequirementSystem.AccountRequirement[] requirements;
        // Quest input tokens
        QuestInput[] inputs;
        // Quest loot rewards
        ILootSystem.Loot[] loots;
        // % chance of completing quest, 0 - 10000 (0 = 0%, 10000 = 100%)
        uint32 baseSuccessProbability;
        // How much time between each completion before it can be repeated
        uint32 cooldownSeconds;
        // 0 = infinite repeatable, 1 = complete only once, 2 = complete twice, etc.
        uint32 maxCompletions;
        // Amount of XP earned on successful completion of this quest
        uint32 successXp;
    }

    struct QuestParams {
        // Id of the quest to start
        uint32 questId;
        // Inputs to the quest
        GameRegistryLibrary.TokenPointer[] inputs;
    }

    // Struct to track and respond to VRF requests
    struct VRFRequest {
        // Account the request is for
        address account;
        // Active Quest ID for the request
        uint64 activeQuestId;
    }

    // Status of an active quest
    enum ActiveQuestStatus {
        UNDEFINED,
        IN_PROGRESS,
        GENERATING_RESULTS,
        COMPLETED
    }

    // Struct to store the data related to a quest undertaken by an account
    struct ActiveQuest {
        // Status of the quest
        ActiveQuestStatus status;
        // Account that undertook the quest
        address account;
        // Id of the quest
        uint32 questId;
        // Time the quest was started
        uint32 startTime;
        // Inputs passed to this quest
        GameRegistryLibrary.ReservedToken[] inputs;
    }

    // Struct to store account-specific data related to quests
    struct AccountData {
        // Currently active quest ids for the account
        EnumerableSet.UintSet activeQuestIds;
        // Number of times this account has completed a given quest
        mapping(uint32 => uint32) completions;
        // Last completion time for a quest
        mapping(uint32 => uint32) lastCompletionTime;
    }

    /** MEMBERS */

    /// @notice Quest definitions
    mapping(uint32 => QuestDefinition) public _questDefinitions;

    /// @notice Currently active quests
    mapping(uint256 => ActiveQuest) public _activeQuests;

    /// @notice Mapping to track VRF requests
    mapping(uint256 => VRFRequest) private _vrfRequests;

    /// @notice Mapping to track which quests require VRF
    mapping(uint32 => bool) private _questNeedsVRF;

    /// @notice Counter to track active quest id
    Counters.Counter private _activeQuestCounter;

    /// @notice Quest data for a given account
    mapping(address => AccountData) private _accountData;

    /// @notice Pending quests for a given account
    mapping(address => mapping(uint32 => uint32)) private _pendingQuests;

    /** ERRORS */

    /// @notice Error thrown when bounty is still running for this NFT
    error BountyStillRunning();

    /** EVENTS */

    /// @notice Emitted when a quest has been updated
    event QuestUpdated(uint32 questId);

    /// @notice Emitted when a quest has been started
    event QuestStarted(address account, uint32 questId, uint256 activeQuestId);

    /// @notice Emitted when a quest has been completed
    event QuestCompleted(
        address account,
        uint32 questId,
        uint256 activeQuestId,
        bool success
    );

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * Sets the definition for a given quest
     * @param questId       Id of the quest to set
     * @param definition    Definition for the quest
     */
    function setQuestDefinition(
        uint32 questId,
        QuestDefinition calldata definition
    ) public onlyRole(MANAGER_ROLE) {
        require(
            definition.inputs.length > 0 && definition.loots.length > 0,
            "MISSING_INPUTS_OR_OUTPUTS"
        );

        // Validate all inputs
        for (uint256 idx = 0; idx < definition.inputs.length; ++idx) {
            QuestInput memory input = definition.inputs[idx];
            require(
                input.tokenPointer.tokenType !=
                    GameRegistryLibrary.TokenType.UNDEFINED,
                "INVALID_INPUT_TOKEN_TYPE"
            );
            require(
                input.xpEarnedPercent == 0 ||
                    input.tokenPointer.tokenType ==
                    GameRegistryLibrary.TokenType.ERC721,
                "XP_EARNED_MUST_BE_ON_ERC721"
            );
        }

        // Validate all requirements
        IRequirementSystem requirementSystem = IRequirementSystem(
            _getSystem(REQUIREMENT_SYSTEM_ID)
        );
        requirementSystem.validateAccountRequirements(definition.requirements);

        _questNeedsVRF[questId] =
            _lootSystem().validateLoots(definition.loots) ||
            _needsVRF(definition);

        // Store definition
        _questDefinitions[questId] = definition;

        // Emit quest definition updated event
        emit QuestUpdated(questId);
    }

    /** @return QuestDefinition for a given questId */
    function getQuestDefinition(
        uint32 questId
    ) external view returns (QuestDefinition memory) {
        return _questDefinitions[questId];
    }

    /**
     * @return All active quest ids for a given account
     */
    function activeQuestIdsForAccount(
        address account
    ) external view returns (uint256[] memory) {
        EnumerableSet.UintSet storage set = _accountData[account]
            .activeQuestIds;
        uint256[] memory result = new uint256[](set.length());

        for (uint16 idx; idx < set.length(); ++idx) {
            result[idx] = set.at(idx);
        }

        return result;
    }

    /** @return ActiveQuest data for a given activeQuestId */
    function getActiveQuest(
        uint256 activeQuestId
    ) external view returns (ActiveQuest memory) {
        return _activeQuests[activeQuestId];
    }

    /**
     * @return completions How many times the quest was completed by the given account
     * @return lastCompletionTime Last completion timestamp for the given quest and account
     */
    function getQuestDataForAccount(
        address account,
        uint32 questId
    )
        external
        view
        override
        returns (uint32 completions, uint32 lastCompletionTime)
    {
        completions = _accountData[account].completions[questId];
        lastCompletionTime = _accountData[account].lastCompletionTime[questId];
    }

    /**
     * Sets whether or not the quest is active
     *
     * @param questId   Id of the quest to change
     * @param enabled    Whether or not the quest should be active
     */
    function setQuestEnabled(
        uint32 questId,
        bool enabled
    ) public onlyRole(MANAGER_ROLE) {
        QuestDefinition storage questDef = _questDefinitions[questId];
        require(questDef.inputs.length > 0, "QUEST_NOT_DEFINED");

        questDef.enabled = enabled;
    }

    /**
     * Whether or not a given quest is available to the given player
     *
     * @param account Account to check if quest is available for
     * @param questId Id of the quest to see is available
     *
     * @return Whether or not the quest is available to the given account
     */
    function isQuestAvailable(
        address account,
        uint32 questId
    ) external view returns (bool) {
        QuestDefinition storage questDef = _questDefinitions[questId];
        return _isQuestAvailable(account, questId, questDef);
    }

    /**
     * How many quests are pending for the given account
     * @param account Account to check
     * @param questId Id of the quest to check
     *
     * @return Number of pending quests
     */
    function getPendingQuests(
        address account,
        uint32 questId
    ) public view returns (uint256) {
        return _pendingQuests[account][questId];
    }

    /**
     * Starts a quest for a user
     *
     * @param params Quest parameters for the quest (See struct definition)
     *
     * @return activeQuestId that was created
     */
    function startQuest(
        QuestParams calldata params
    ) external nonReentrant whenNotPaused returns (uint256) {
        QuestDefinition storage questDef = _questDefinitions[params.questId];
        address account = _getPlayerAccount(_msgSender());

        // Verify user can start this quest and meets requirements
        require(
            _isQuestAvailable(account, params.questId, questDef) == true,
            "QUEST_NOT_AVAILABLE"
        );
        require(
            params.inputs.length == questDef.inputs.length,
            "INPUT_LENGTH_MISMATCH"
        );

        // Create active quest object
        _activeQuestCounter.increment();
        uint256 activeQuestId = _activeQuestCounter.current();

        ActiveQuest storage activeQuest = _activeQuests[activeQuestId];
        activeQuest.account = account;
        activeQuest.questId = params.questId;
        activeQuest.startTime = SafeCast.toUint32(block.timestamp);
        activeQuest.status = ActiveQuestStatus.IN_PROGRESS;

        // Track activeQuestId for this account
        _accountData[account].activeQuestIds.add(activeQuestId);

        // Verify that the params have inputs that meet the quest requirements
        for (uint8 idx; idx < questDef.inputs.length; ++idx) {
            QuestInput storage inputDef = questDef.inputs[idx];
            GameRegistryLibrary.TokenPointer storage tokenPointerDef = inputDef
                .tokenPointer;

            GameRegistryLibrary.TokenPointer memory input = params.inputs[idx];

            // Make sure that token type matches between definition and id
            require(
                input.tokenType == tokenPointerDef.tokenType,
                "TOKEN_TYPE_NOT_MATCHING"
            );

            // If Quest definition TokenPointer is Pirate NFT check that input is either Pirate NFT or Starter Pirate NFT
            if (tokenPointerDef.tokenContract == _getSystem(PIRATE_NFT_ID)) {
                require(
                    isPirateNFT(input.tokenContract, input.tokenId),
                    "TOKEN_CONTRACT_NOT_MATCHING"
                );
            } else {
                // Else perform standard check that definition and input token contracts match
                require(
                    tokenPointerDef.tokenContract == address(0) ||
                        tokenPointerDef.tokenContract == input.tokenContract,
                    "TOKEN_CONTRACT_NOT_MATCHING"
                );
            }

            // Make sure token id match between definition and input
            require(
                tokenPointerDef.tokenId == 0 ||
                    tokenPointerDef.tokenId == input.tokenId,
                "TOKEN_ID_NOT_MATCHING"
            );

            GameHelperLibrary._verifyInputOwnership(input, account);

            GameRegistryLibrary.TokenType tokenType = tokenPointerDef.tokenType;
            uint32 reservationId = 0;

            // Check token type to ensure that the input matches what the quest expects
            if (tokenType == GameRegistryLibrary.TokenType.ERC20) {
                require(
                    _hasAccessRole(
                        GAME_CURRENCY_CONTRACT_ROLE,
                        input.tokenContract
                    ) == true,
                    "NOT_GAME_CURRENCY"
                );

                // Burn ERC20 immediately, will be refunded if not consumable later
                IGameCurrency(input.tokenContract).burn(account, input.amount);
            } else if (tokenType == GameRegistryLibrary.TokenType.ERC721) {
                // Spend Wallet energy if needed
                if (inputDef.energyRequired > 0) {
                    // Subtract energy from user wallet entity
                    IEnergySystemV3(_getSystem(ENERGY_SYSTEM_ID)).spendEnergy(
                        EntityLibrary.addressToEntity(account),
                        inputDef.energyRequired
                    );
                }
            } else if (tokenType == GameRegistryLibrary.TokenType.ERC1155) {
                // Burn ERC1155 inputs immediately, refund if they don't need to be burned
                IGameItems(input.tokenContract).burn(
                    account,
                    input.tokenId,
                    tokenPointerDef.amount
                );
            }

            // Perform all trait checks
            ITraitsProvider traitsProvider = _traitsProvider();

            for (
                uint8 traitIdx;
                traitIdx < inputDef.traitChecks.length;
                traitIdx++
            ) {
                TraitsLibrary.requireTraitCheck(
                    traitsProvider,
                    inputDef.traitChecks[traitIdx],
                    input.tokenContract,
                    input.tokenId
                );
            }

            activeQuest.inputs.push(
                GameRegistryLibrary.ReservedToken({
                    tokenType: input.tokenType,
                    tokenId: input.tokenId,
                    tokenContract: input.tokenContract,
                    amount: tokenPointerDef.amount,
                    reservationId: reservationId
                })
            );
        }

        _pendingQuests[account][params.questId] += 1;

        emit QuestStarted(account, params.questId, activeQuestId);

        if (_questNeedsVRF[params.questId] == false) {
            _completeQuest(account, activeQuest, activeQuestId, true, 0);
        } else {
            // Start the completion process immediately
            uint256 requestId = _requestRandomWords(1);
            _vrfRequests[requestId] = VRFRequest({
                account: account,
                activeQuestId: SafeCast.toUint64(activeQuestId)
            });
        }

        return activeQuestId;
    }

    /**
     * Finishes quest with randomness
     */
    function fulfillRandomWordsCallback(
        uint256 requestId,
        uint256[] memory randomWords
    ) external override onlyRole(RANDOMIZER_ROLE) {
        VRFRequest storage request = _vrfRequests[requestId];
        address account = request.account;

        if (account != address(0)) {
            uint256 activeQuestId = request.activeQuestId;

            ActiveQuest storage activeQuest = _activeQuests[activeQuestId];

            QuestDefinition storage questDef = _questDefinitions[
                activeQuest.questId
            ];

            // Calculate whether or not quest was successful
            (bool success, uint256 nextRandomWord) = RandomLibrary
                .weightedCoinFlip(
                    randomWords[0],
                    questDef.baseSuccessProbability
                );

            _completeQuest(
                account,
                activeQuest,
                activeQuestId,
                success,
                nextRandomWord
            );

            // Delete the VRF request
            delete _vrfRequests[requestId];
        }
    }

    /** INTERNAL **/

    /**
     * Completes a quest for a user
     *
     * @param account Account of the quest to be completed
     * @param activeQuest the active quest beign completed
     * @param activeQuestId Id of the ActiveQuest to be completed
     * @param success was the quest successfully completed
     * @param nextRandomWord random word
     *
     */
    function _completeQuest(
        address account,
        ActiveQuest storage activeQuest,
        uint256 activeQuestId,
        bool success,
        uint256 nextRandomWord
    ) internal {
        if (success) {
            _questSuccess(account, activeQuest, nextRandomWord);
        } else {
            _questFailed(account, activeQuest, nextRandomWord);
        }

        // Emit completed event
        emit QuestCompleted(
            account,
            activeQuest.questId,
            activeQuestId,
            success
        );

        // Subtract pending quests
        _pendingQuests[account][activeQuest.questId] -= 1;

        // Change quest status to completed
        activeQuest.status = ActiveQuestStatus.COMPLETED;

        // Remove from activeQuestId array
        _accountData[account].activeQuestIds.remove(activeQuestId);
    }

    /**
     * checks if a quest is available
     *
     * @param account Account to be checked
     * @param questId questId to be checked
     * @param questDef definition of the quest to be checked
     *
     * @return bool
     *
     */
    function _isQuestAvailable(
        address account,
        uint32 questId,
        QuestDefinition memory questDef
    ) internal view returns (bool) {
        if (!questDef.enabled) {
            return false;
        }

        // Perform all requirement checks
        IRequirementSystem requirementSystem = IRequirementSystem(
            _getSystem(REQUIREMENT_SYSTEM_ID)
        );
        if (
            requirementSystem.performAccountCheckBatch(
                account,
                questDef.requirements
            ) == false
        ) {
            return false;
        }

        // Make sure user hasn't completed already
        AccountData storage accountData = _accountData[account];
        if (
            questDef.maxCompletions > 0 &&
            accountData.completions[questId] >= questDef.maxCompletions
        ) {
            return false;
        }

        // Make sure enough time has passed before completions
        if (questDef.cooldownSeconds > 0) {
            // make sure no quests are currently pending
            if (_pendingQuests[account][questId] > 0) {
                return false;
            }

            // Make sure cooldown has passed
            if (
                accountData.lastCompletionTime[questId] +
                    questDef.cooldownSeconds >
                block.timestamp
            ) {
                return false;
            }
        }
        return true;
    }

    /**
     * Quest fail handler
     *
     * @param account Account to be checked
     * @param activeQuest the active quest to be checked
     * @param randomWord a  random word
     *
     */
    function _questFailed(
        address account,
        ActiveQuest storage activeQuest,
        uint256 randomWord
    ) internal {
        QuestDefinition storage questDef = _questDefinitions[
            activeQuest.questId
        ];

        _unlockQuestInputs(account, questDef, activeQuest, false, randomWord);
    }

    /**
     * Quest success handler
     *
     * @param account Account to be checked
     * @param activeQuest the active quest to be checked
     * @param randomWord a  random word
     *
     */
    function _questSuccess(
        address account,
        ActiveQuest storage activeQuest,
        uint256 randomWord
    ) internal {
        uint32 questId = activeQuest.questId;
        QuestDefinition storage questDef = _questDefinitions[questId];

        // Unlock quest inputs and optionally grant XP
        _unlockQuestInputs(account, questDef, activeQuest, true, randomWord);

        // Grant quest loot
        _lootSystem().grantLootWithRandomWord(
            account,
            questDef.loots,
            randomWord
        );

        // Track account specific completion data
        AccountData storage accountData = _accountData[account];
        accountData.lastCompletionTime[questId] = SafeCast.toUint32(
            block.timestamp
        );
        accountData.completions[questId]++;
    }

    /**
     * Unlock a quest input
     *
     * @param account Account with the quest
     * @param questDef quest definition
     * @param activeQuest tthe active quest
     * @param isSuccess was successful
     * @param randomWord random word
     *
     */
    function _unlockQuestInputs(
        address account,
        QuestDefinition storage questDef,
        ActiveQuest storage activeQuest,
        bool isSuccess,
        uint256 randomWord
    ) internal {
        uint32 successXp = isSuccess ? questDef.successXp : 0;

        // Unlock inputs, grant XP, and potentially burn inputs
        for (uint8 idx; idx < questDef.inputs.length; ++idx) {
            QuestInput storage input = questDef.inputs[idx];
            GameRegistryLibrary.ReservedToken
                storage activeQuestInput = activeQuest.inputs[idx];

            // Grant XP on success
            if (successXp > 0 && input.xpEarnedPercent > 0) {
                uint256 xpAmount = (successXp * input.xpEarnedPercent) /
                    PERCENTAGE_RANGE;

                if (xpAmount > 0) {
                    ILevelSystem levelSystem = ILevelSystem(
                        _getSystem(LEVEL_SYSTEM_ID)
                    );
                    levelSystem.grantXP(
                        activeQuestInput.tokenContract,
                        activeQuestInput.tokenId,
                        xpAmount
                    );
                }
            }

            // Determine if the input should be refunded to the user
            bool shouldBurn;

            if (input.consumable) {
                uint256 burnProbability = isSuccess
                    ? input.successBurnProbability
                    : input.failureBurnProbability;

                if (burnProbability == 0) {
                    shouldBurn = false;
                } else if (burnProbability >= PERCENTAGE_RANGE) {
                    shouldBurn = true;
                } else {
                    randomWord = RandomLibrary.generateNextRandomWord(
                        randomWord
                    );
                    (shouldBurn, randomWord) = RandomLibrary.weightedCoinFlip(
                        randomWord,
                        burnProbability
                    );
                }

                // Unlock/burn based on token type
                if (
                    activeQuestInput.tokenType ==
                    GameRegistryLibrary.TokenType.ERC20
                ) {
                    // If we are not burning, refund the ERC20
                    if (shouldBurn == false) {
                        IGameCurrency(activeQuestInput.tokenContract).mint(
                            account,
                            activeQuestInput.amount
                        );
                    }
                } else if (
                    activeQuestInput.tokenType ==
                    GameRegistryLibrary.TokenType.ERC1155
                ) {
                    if (shouldBurn == false) {
                        // If we are not burning, refund the amount
                        IGameItems(activeQuestInput.tokenContract).mint(
                            account,
                            SafeCast.toUint32(activeQuestInput.tokenId),
                            activeQuestInput.amount
                        );
                    }
                }
            }
        }
    }

    /**
     * checks is a quest requires VRF
     *
     * @param definition the definition of the quest to be verified
     *
     * @return bool
     */
    function _needsVRF(
        QuestDefinition memory definition
    ) internal pure returns (bool) {
        if (
            definition.baseSuccessProbability < PERCENTAGE_RANGE &&
            definition.baseSuccessProbability != 0
        ) {
            return true;
        }

        QuestInput[] memory inputs = definition.inputs;

        for (uint8 i; i < inputs.length; ++i) {
            if (
                inputs[i].successBurnProbability < PERCENTAGE_RANGE &&
                inputs[i].successBurnProbability != 0
            ) {
                return true;
            }
            if (
                inputs[i].failureBurnProbability < PERCENTAGE_RANGE &&
                inputs[i].failureBurnProbability != 0
            ) {
                return true;
            }
        }
        return false;
    }

    function isPirateNFT(
        address tokenContract,
        uint256 tokenId
    ) internal view returns (bool) {
        return (_hasAccessRole(GAME_NFT_CONTRACT_ROLE, tokenContract) &&
            _traitsProvider().hasTrait(
                tokenContract,
                tokenId,
                IS_PIRATE_TRAIT_ID
            ));
    }
}
