// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../libraries/GameRegistryLibrary.sol";
import "../libraries/GameHelperLibrary.sol";
import "../libraries/TraitsLibrary.sol";
import "../libraries/RandomLibrary.sol";

import {MANAGER_ROLE, RANDOMIZER_ROLE, GAME_CURRENCY_CONTRACT_ROLE} from "../Constants.sol";
import {IGameItems} from "../tokens/gameitems/IGameItems.sol";
import {IGameCurrency} from "../tokens/IGameCurrency.sol";
import {ITraitsProvider, ID as TRAITS_PROVIDER_ID} from "../interfaces/ITraitsProvider.sol";
import {ILootSystem} from "../loot/ILootSystem.sol";
import {ILevelSystem, ID as LEVEL_SYSTEM_ID} from "../level/ILevelSystem.sol";
import {IRequirementSystem, ID as REQUIREMENT_SYSTEM_ID} from "../requirements/IRequirementSystem.sol";

import "../GameRegistryConsumerUpgradeable.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.craftingsystem"));

contract CraftingSystem is GameRegistryConsumerUpgradeable {
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;

    struct RecipeInput {
        // Pointer to a token (if ERC20, ERC721, or ERC1155 input type)
        GameRegistryLibrary.TokenPointer tokenPointer;
        // Traits to check against
        TraitCheck[] traitChecks;
        // Whether or not this input is required
        bool required;
        // Whether or not the input is burned
        bool consumable;
        // Chance of losing the consumable item on a failure, 0 - 10000 (0 = 0%, 10000 = 100%)
        uint256 failureBurnProbability;
        // Chance of burning the consumable item on success, 0 - 10000 (0 = 0%, 10000 = 100%)
        uint256 successBurnProbability;
        // Amount of XP gained by this input (ERC721-types only, 0 - 10000 (0 = 0%, 10000 = 100%))
        uint32 xpEarnedPercent;
    }

    // Full definition for a recipe
    struct RecipeDefinition {
        // Whether or not the recipe is active
        bool enabled;
        // Requirements before recipe can be used
        IRequirementSystem.AccountRequirement[] requirements;
        // Recipe input tokens
        RecipeInput[] inputs;
        // Craft loot rewards
        ILootSystem.Loot[] loots;
        // % chance of completing craft successfully, 0 - 10000 (0 = 0%, 10000 = 100%)
        uint32 baseSuccessProbability;
        // How much time between each successful completion before it can be repeated
        uint32 cooldownSeconds;
        // Amount of XP to grant on success
        uint32 successXp;
        // maximum allowed completions
        uint32 maxCompletions;
    }

    struct CraftParams {
        // Id of the recipe to craft
        uint32 recipeId;
        // Inputs to the craft
        GameRegistryLibrary.TokenPointer[] inputs;
        // Amount of times to craft this recipe (inputs must be scaled accordingly)
        uint8 craftAmount;
    }

    // Struct to track and respond to VRF requests
    struct VRFRequest {
        // Account the request is for
        address account;
        // Id of the ActiveCraft object
        uint256 activeCraftId;
    }

    // Struct to store account-specific data related to recipes
    struct AccountData {
        // Currently active requests for the account
        EnumerableSet.UintSet activeCraftIds;
        // Number of times this account has completed a given recipe
        mapping(uint32 => uint32) completions;
        // Last completion time for a recipe
        mapping(uint32 => uint256) lastCompletionTime;
    }

    // Status of an active craft
    enum ActiveCraftStatus {
        UNDEFINED,
        IN_PROGRESS,
        COMPLETED
    }

    // Struct to store the data related to a craft undertaken by an account
    struct ActiveCraft {
        // Status of the quest
        ActiveCraftStatus status;
        // Account that undertook the quest
        address account;
        // Id of the recipe being crafted
        uint32 recipeId;
        // Inputs passed to this quest
        GameRegistryLibrary.ReservedToken[] inputs;
        // Amount of times to craft the recipe
        uint8 craftAmount;
    }

    /** MEMBERS */

    /// @notice Currently active crafts
    mapping(uint256 => ActiveCraft) private _activeCrafts;

    /// @notice Counter to track active craft id
    Counters.Counter private _activeCraftCounter;

    /// @notice Recipe definitions
    mapping(uint32 => RecipeDefinition) private _recipeDefinitions;

    /// @notice Mapping to track VRF requests
    mapping(uint256 => VRFRequest) private _vrfRequests;

    /// @notice Mapping to track which recipes require VRF
    mapping(uint32 => bool) private _recipeNeedsVRF;

    /// @notice Recipe data for a given account
    mapping(address => AccountData) private _accountData;

    /** EVENTS */

    /// @notice Emitted when a recipe has been updated
    event RecipeUpdated(uint32 recipeId);

    /// @notice Emitted when a craft has been started
    event CraftStarted(
        address account,
        uint32 recipeId,
        uint32 amount,
        uint256 activeCraftId
    );

    /// @notice Emitted when a craft has been completed
    event CraftCompleted(
        address account,
        uint32 recipeId,
        uint32 amount,
        uint256 activeCraftId,
        uint8 successCount
    );

    /** ERRORS **/

    /// @dev Expected inputs and outputs to both exist
    error InvalidInputsOrOutputs();

    /// @dev Recipe has not been defined
    error RecipeNotDefined(uint32 recipeId);

    /// @dev Recipe is not available for crafting
    error RecipeNotAvailable(address account, uint32 recipeId);

    /// @dev Inputs provided does not match recipe definition
    error InputLengthMismatch(uint256 expected, uint256 actual);

    /// @dev Invalid craft amount specified
    error InvalidCraftAmount();

    /// @dev Token type doesn't match expected input
    error TokenTypeNotMatching(
        GameRegistryLibrary.TokenType expected,
        GameRegistryLibrary.TokenType actual
    );

    /// @dev Token contract doesn't match expected input
    error TokenContractNotMatching(address expected, address actual);

    /// @dev TokenId doesn't match expected input
    error TokenIdNotMatching(uint256 expected, uint256 actual);

    /// @dev Got trait checks for an ERC20
    error IncorrectTraitChecks();

    /** EXTERNAL **/

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * Sets the definition for a given recipe
     * @param recipeId       Id of the recipe to set
     * @param definition    Definition for the recipe
     */
    function setRecipeDefinition(
        uint32 recipeId,
        RecipeDefinition calldata definition
    ) public onlyRole(MANAGER_ROLE) {
        if (definition.inputs.length == 0 || definition.loots.length == 0) {
            revert InvalidInputsOrOutputs();
        }

        // Validate all requirements
        IRequirementSystem requirementSystem = IRequirementSystem(
            _getSystem(REQUIREMENT_SYSTEM_ID)
        );
        requirementSystem.validateAccountRequirements(definition.requirements);

        // Store definition
        _recipeDefinitions[recipeId] = definition;

        _recipeNeedsVRF[recipeId] =
            _lootSystem().validateLoots(definition.loots) ||
            _needsVRF(definition);

        // Emit recipe definition updated event
        emit RecipeUpdated(recipeId);
    }

    /**
     * @param recipeId Id of the RecipeDefinition to retrieve
     * @return RecipeDefinition for a given recipeId
     */
    function getRecipeDefinition(
        uint32 recipeId
    ) external view returns (RecipeDefinition memory) {
        return _recipeDefinitions[recipeId];
    }

    /**
     * @param account Account to get active craft ids for
     * @return All active recipe ids for a given account
     */
    function activeCraftIdsForAccount(
        address account
    ) external view returns (uint256[] memory) {
        EnumerableSet.UintSet storage set = _accountData[account]
            .activeCraftIds;
        uint256[] memory result = new uint256[](set.length());

        for (uint16 idx; idx < set.length(); ++idx) {
            result[idx] = set.at(idx);
        }

        return result;
    }

    /**
     * @param activeCraftId Id of the ActiveCraft to retrieve
     * @return ActiveCraft data for a given activeCraftId
     */
    function getActiveCraft(
        uint256 activeCraftId
    ) external view returns (ActiveCraft memory) {
        return _activeCrafts[activeCraftId];
    }

    /**
     * @param account Account to get data for
     * @param recipeId Recipe to get account data for
     * @return completions How many times the recipe was completed by the given account
     * @return lastCompletionTime Last completion timestamp for the given recipe and account
     */
    function getRecipeDataForAccount(
        address account,
        uint32 recipeId
    ) external view returns (uint32 completions, uint256 lastCompletionTime) {
        completions = _accountData[account].completions[recipeId];
        lastCompletionTime = _accountData[account].lastCompletionTime[recipeId];
    }

    /**
     * Sets whether or not the recipe is active
     *
     * @param recipeId   Id of the recipe to change
     * @param enabled    Whether or not the recipe should be active
     */
    function setRecipeEnabled(
        uint32 recipeId,
        bool enabled
    ) public onlyRole(MANAGER_ROLE) {
        RecipeDefinition storage recipeDef = _recipeDefinitions[recipeId];
        if (recipeDef.inputs.length == 0) {
            revert RecipeNotDefined(recipeId);
        }

        recipeDef.enabled = enabled;
    }

    /**
     * Whether or not a given recipe is available to the given player
     *
     * @param account Account to check if recipe is available for
     * @param recipeId Id of the recipe to see is available
     *
     * @return Whether or not the recipe is available to the given account
     */
    function isRecipeAvailable(
        address account,
        uint32 recipeId
    ) external view returns (bool) {
        RecipeDefinition storage recipeDef = _recipeDefinitions[recipeId];
        return _isRecipeAvailable(account, recipeId, recipeDef);
    }

    /**
     * Starts a recipe for a user
     *
     * @param params Recipe parameters for the recipe (See struct definition)
     *
     * @return activeCraftId that was created
     */
    function craft(
        CraftParams calldata params
    ) external nonReentrant whenNotPaused returns (uint256) {
        uint32 recipeId = params.recipeId;
        uint8 craftAmount = params.craftAmount;
        RecipeDefinition storage recipeDef = _recipeDefinitions[recipeId];
        address account = _getPlayerAccount(_msgSender());

        // Verify user can start this recipe and meets requirements
        if (_isRecipeAvailable(account, recipeId, recipeDef) == false) {
            revert RecipeNotAvailable(account, recipeId);
        }

        if (params.inputs.length != recipeDef.inputs.length) {
            revert InputLengthMismatch(
                recipeDef.inputs.length,
                params.inputs.length
            );
        }

        if (craftAmount == 0) {
            revert InvalidCraftAmount();
        }
        // Create active recipe object
        _activeCraftCounter.increment();
        uint256 activeCraftId = _activeCraftCounter.current();

        ActiveCraft storage activeCraft = _activeCrafts[activeCraftId];
        activeCraft.account = account;
        activeCraft.recipeId = recipeId;
        activeCraft.status = ActiveCraftStatus.IN_PROGRESS;
        activeCraft.craftAmount = craftAmount;

        // Track activeCraftId for this account
        _accountData[account].activeCraftIds.add(activeCraftId);

        // Verify that the params have inputs that meet the recipe requirements
        for (uint8 idx; idx < recipeDef.inputs.length; ++idx) {
            RecipeInput storage inputDef = recipeDef.inputs[idx];
            GameRegistryLibrary.TokenPointer storage tokenPointerDef = inputDef
                .tokenPointer;

            GameRegistryLibrary.TokenType tokenType = tokenPointerDef.tokenType;
            GameRegistryLibrary.TokenPointer memory input = params.inputs[idx];
            address tokenContract = input.tokenContract;
            uint256 tokenId = input.tokenId;

            // Make sure that token type matches between definition and id
            if (input.tokenType != tokenType) {
                revert TokenTypeNotMatching(tokenType, input.tokenType);
            }

            // Make sure token contracts match between definition and input
            if (
                tokenPointerDef.tokenContract != address(0) &&
                tokenPointerDef.tokenContract != tokenContract
            ) {
                revert TokenContractNotMatching(
                    tokenPointerDef.tokenContract,
                    tokenContract
                );
            }

            // Make sure token id match between definition and input
            if (
                tokenPointerDef.tokenId != 0 &&
                tokenPointerDef.tokenId != tokenId
            ) {
                revert TokenIdNotMatching(tokenPointerDef.tokenId, tokenId);
            }

            GameHelperLibrary._verifyInputOwnership(input, account);

            uint32 reservationId = 0;

            uint256 requiredInputAmount = tokenPointerDef.amount * craftAmount;
            ITraitsProvider traitsProvider = ITraitsProvider(
                _getSystem(TRAITS_PROVIDER_ID)
            );

            for (
                uint8 traitIdx;
                traitIdx < inputDef.traitChecks.length;
                traitIdx++
            ) {
                TraitsLibrary.requireTraitCheck(
                    traitsProvider,
                    inputDef.traitChecks[traitIdx],
                    tokenContract,
                    tokenId
                );
            }

            // Check token type to ensure that the input matches what the recipe expects
            if (tokenType == GameRegistryLibrary.TokenType.ERC20) {
                require(
                    _hasAccessRole(
                        GAME_CURRENCY_CONTRACT_ROLE,
                        tokenContract
                    ) && inputDef.consumable,
                    "NOT_CONSUMABLE_GAME_CURRENCY"
                );
                // Burn ERC20 immediately
                IGameCurrency(tokenContract).burn(account, requiredInputAmount);
            } else if (tokenType == GameRegistryLibrary.TokenType.ERC721) {
                // Add hold on NFT
                ILockingSystem lockingSystem = _lockingSystem();

                reservationId = lockingSystem.addNFTReservation(
                    tokenContract,
                    tokenId,
                    true,
                    GameRegistryLibrary.RESERVATION_CRAFTING_SYSTEM
                );
            } else if (tokenType == GameRegistryLibrary.TokenType.ERC1155) {
                // Burn item inputs immediately
                if (inputDef.consumable) {
                    IGameItems(tokenContract).burn(
                        account,
                        tokenId,
                        requiredInputAmount
                    );
                } else {
                    // If item is not consumable, put a reservation on it
                    reservationId = _lockingSystem().addItemReservation(
                        account,
                        tokenContract,
                        tokenId,
                        requiredInputAmount,
                        true,
                        GameRegistryLibrary.RESERVATION_CRAFTING_SYSTEM
                    );
                }
            }

            activeCraft.inputs.push(
                GameRegistryLibrary.ReservedToken({
                    tokenType: tokenType,
                    tokenContract: tokenContract,
                    tokenId: tokenId,
                    amount: requiredInputAmount,
                    reservationId: reservationId
                })
            );
        }

        emit CraftStarted(account, recipeId, craftAmount, activeCraftId);

        if (_recipeNeedsVRF[recipeId] == false) {
            _completeRecipe(account, recipeId, activeCraftId, craftAmount, 0);
        } else {
            // Start randomness
            uint256 requestId = _requestRandomWords(1);
            _vrfRequests[requestId] = VRFRequest({
                account: account,
                activeCraftId: activeCraftId
            });
        }

        return activeCraftId;
    }

    /**
     * Finishes recipe with randomness
     * @inheritdoc GameRegistryConsumerUpgradeable
     */
    function fulfillRandomWordsCallback(
        uint256 requestId,
        uint256[] memory randomWords
    ) external override onlyRole(RANDOMIZER_ROLE) {
        VRFRequest storage request = _vrfRequests[requestId];
        address account = request.account;
        uint256 randomWord = randomWords[0];
        if (account != address(0)) {
            uint256 activeCraftId = request.activeCraftId;
            ActiveCraft storage activeCraft = _activeCrafts[activeCraftId];
            uint32 recipeId = activeCraft.recipeId;
            RecipeDefinition storage recipeDef = _recipeDefinitions[recipeId];

            // Calculate how many crafts were successful
            (uint16 numSuccess, uint256 nextRandomWord) = RandomLibrary
                .weightedCoinFlipBatch(
                    randomWord,
                    recipeDef.baseSuccessProbability,
                    activeCraft.craftAmount
                );

            _completeRecipe(
                account,
                recipeId,
                activeCraftId,
                uint8(numSuccess),
                nextRandomWord
            );
        }

        // Delete the VRF request
        delete _vrfRequests[requestId];
    }

    /** INTERNAL **/

    /**
     * Completes a recipe for a user
     *
     * @param account Account to get active craft id to be completed
     * @param recipeId Id of the recipe to being crafted
     * @param activeCraftId Id of the ActiveCraft to be completed
     * @param numSuccess number of success crafts
     * @param nextRandomWord random word
     *
     */
    function _completeRecipe(
        address account,
        uint32 recipeId,
        uint256 activeCraftId,
        uint8 numSuccess,
        uint256 nextRandomWord
    ) internal {
        ActiveCraft storage activeCraft = _activeCrafts[activeCraftId];
        RecipeDefinition storage recipeDef = _recipeDefinitions[recipeId];
        uint8 craftAmount = activeCraft.craftAmount;

        if (numSuccess > 0) {
            // Has randomness
            if (nextRandomWord > 0) {
                for (uint8 grantIdx; grantIdx < numSuccess; grantIdx++) {
                    nextRandomWord = RandomLibrary.generateNextRandomWord(
                        nextRandomWord
                    );
                    _lootSystem().grantLootWithRandomWord(
                        account,
                        recipeDef.loots,
                        nextRandomWord
                    );
                }
            } else {
                // No randomness, simply grant the loot
                _lootSystem().batchGrantLootWithoutRandomness(
                    account,
                    recipeDef.loots,
                    numSuccess
                );
            }
        }

        // Unlock inputs and grant XP
        uint256 successXp = recipeDef.successXp * numSuccess;
        for (uint16 idx; idx < recipeDef.inputs.length; ++idx) {
            RecipeInput storage input = recipeDef.inputs[idx];
            GameRegistryLibrary.ReservedToken
                storage activeCraftInput = activeCraft.inputs[idx];

            // Unlock input
            _unlockRecipeInput(
                account,
                input,
                activeCraftInput,
                craftAmount,
                numSuccess,
                nextRandomWord
            );

            // Grant XP
            if (successXp > 0 && input.xpEarnedPercent > 0) {
                uint256 xpAmount = (successXp * input.xpEarnedPercent) /
                    PERCENTAGE_RANGE;
                if (xpAmount > 0) {
                    ILevelSystem levelSystem = ILevelSystem(
                        _getSystem(LEVEL_SYSTEM_ID)
                    );
                    levelSystem.grantXP(
                        activeCraftInput.tokenContract,
                        activeCraftInput.tokenId,
                        xpAmount
                    );
                }
            }
        }

        AccountData storage accountData = _accountData[account];

        accountData.completions[recipeId] += numSuccess;
        // Emit completed event
        emit CraftCompleted(
            account,
            recipeId,
            craftAmount,
            activeCraftId,
            numSuccess
        );

        // Change recipe status to completed
        activeCraft.status = ActiveCraftStatus.COMPLETED;

        // Remove from activeCraftId array
        accountData.activeCraftIds.remove(activeCraftId);
        accountData.lastCompletionTime[recipeId] = block.timestamp;
    }

    /**
     * Checks if a recipe is available
     *
     * @param account Account with the recipe
     * @param recipeId Id of the recipe to be verified
     *
     */
    function _isRecipeAvailable(
        address account,
        uint32 recipeId,
        RecipeDefinition memory recipeDef
    ) internal view returns (bool) {
        if (!recipeDef.enabled) {
            return false;
        }

        // Perform all requirement checks
        IRequirementSystem requirementSystem = IRequirementSystem(
            _getSystem(REQUIREMENT_SYSTEM_ID)
        );
        if (
            requirementSystem.performAccountCheckBatch(
                account,
                recipeDef.requirements
            ) == false
        ) {
            return false;
        }

        AccountData storage accountData = _accountData[account];

        // Make sure user hasn't completed already
        if (
            recipeDef.maxCompletions > 0 &&
            accountData.completions[recipeId] >= recipeDef.maxCompletions
        ) {
            return false;
        }

        // Make sure enough time has passed before completions
        if (recipeDef.cooldownSeconds > 0) {
            if (
                accountData.lastCompletionTime[recipeId] +
                    recipeDef.cooldownSeconds >
                block.timestamp
            ) {
                return false;
            }
        }

        return true;
    }

    /**
     * Unlock a recipe input
     *
     * @param account Account with the recipe
     * @param input input to be unlocked
     * @param reservedToken the token of the input
     * @param craftAmount number of crafts being performed in the batch
     * @param numSuccess number of success crafts
     * @param randomWord random word
     *
     */
    function _unlockRecipeInput(
        address account,
        RecipeInput storage input,
        GameRegistryLibrary.ReservedToken storage reservedToken,
        uint8 craftAmount,
        uint8 numSuccess,
        uint256 randomWord
    ) internal {
        // Unlock/burn based on token type
        if (reservedToken.tokenType == GameRegistryLibrary.TokenType.ERC721) {
            _lockingSystem().removeNFTReservation(
                reservedToken.tokenContract,
                reservedToken.tokenId,
                reservedToken.reservationId
            );
        } else if (
            reservedToken.tokenType == GameRegistryLibrary.TokenType.ERC1155
        ) {
            // Remove item reservation if it exists
            if (reservedToken.reservationId > 0) {
                _lockingSystem().removeItemReservation(
                    account,
                    reservedToken.tokenContract,
                    reservedToken.tokenId,
                    reservedToken.reservationId
                );
            }

            // Potentially mint/refund ingredients to the user if they aren't consumed
            // Requires a randomWord > 0, otherwise we assume no randomness
            if (input.consumable) {
                uint256 totalMint;

                // A random word was provided, run coinflips
                if (randomWord > 0) {
                    uint16 numFail = craftAmount - numSuccess;
                    (uint16 numSuccessBurn, uint256 randomWord2) = RandomLibrary
                        .weightedCoinFlipBatch(
                            randomWord,
                            input.successBurnProbability,
                            numSuccess
                        );
                    (uint16 numFailBurn, ) = RandomLibrary
                        .weightedCoinFlipBatch(
                            randomWord2,
                            input.failureBurnProbability,
                            numFail
                        );
                    totalMint =
                        (craftAmount - numSuccessBurn - numFailBurn) *
                        input.tokenPointer.amount;
                } else if (input.successBurnProbability == 0) {
                    // Always refund if we have no randomness
                    totalMint = craftAmount;
                }

                // Whatever wasn't burned we should refund to the user
                if (totalMint > 0) {
                    IGameItems gameItems = IGameItems(
                        reservedToken.tokenContract
                    );

                    // Mint items
                    gameItems.mint(
                        account,
                        SafeCast.toUint32(reservedToken.tokenId),
                        totalMint
                    );
                }
            }
        }
    }

    /**
     * checks is a recipe requires VRF
     *
     * @param definition the definition of the recipe to be verified
     *
     */
    function _needsVRF(
        RecipeDefinition memory definition
    ) internal pure returns (bool) {
        if (
            definition.baseSuccessProbability < PERCENTAGE_RANGE &&
            definition.baseSuccessProbability != 0
        ) {
            return true;
        }

        RecipeInput[] memory inputs = definition.inputs;

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
}
