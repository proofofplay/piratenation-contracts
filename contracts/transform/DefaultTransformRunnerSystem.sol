// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import "../libraries/RandomLibrary.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";

import {TransformLibrary} from "./TransformLibrary.sol";
import {ITransformRunnerSystem, TransformParams} from "./ITransformRunnerSystem.sol";
import {DefaultTransformRunnerConfigComponent, Layout as DefaultTransformRunnerConfigComponentLayout, ID as DEFAULT_TRANSFORM_RUNNER_CONFIG_COMPONENT_ID} from "../generated/components/DefaultTransformRunnerConfigComponent.sol";
import {LootEntityArrayComponent, Layout as LootEntityArrayComponentLayout} from "../generated/components/LootEntityArrayComponent.sol";
import {BaseTransformRunnerSystem, TransformInputComponentLayout, TransformInstanceComponentLayout} from "./BaseTransformRunnerSystem.sol";
import {TransformRefundComponent, Layout as TransformRefundComponentLayout, ID as TRANSFORM_REFUND_COMPONENT_ID} from "../generated/components/TransformRefundComponent.sol";
import {TransformAccountDataComponent, Layout as TransformAccountDataComponentLayout, ID as TRANSFORM_ACCOUNT_DATA_COMPONENT_ID} from "../generated/components/TransformAccountDataComponent.sol";
import {ILootSystemV2} from "../loot/ILootSystemV2.sol";
import {IGameCurrency} from "../tokens/IGameCurrency.sol";
import {IGameItems} from "../tokens/gameitems/IGameItems.sol";

import "../GameRegistryConsumerUpgradeable.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.defaulttransformrunnersystem")
);

contract DefaultTransformRunnerSystem is BaseTransformRunnerSystem {
    /** ERRORS */

    /// @notice Error thrown when input length does not match transform definition
    error InputLengthMismatch(uint256 expected, uint256 actual);

    /// @notice Error thrown when missing inputs or outputs for a transform
    error MissingInputsOrOutputs();

    /// @notice Error thrown when a transform input token type is invalid
    error InvalidInputTokenType();

    /// @notice Error thrown when an ERC20 input is invalid
    error InvalidERC20Input();

    /// @notice Error thrown when an ERC721 input is invalid
    error InvalidERC721Input();

    /// @notice Error thrown when token type does not match
    error TokenTypeNotMatching(
        ILootSystemV2.LootType expected,
        ILootSystemV2.LootType actual
    );

    /// @notice Error thrown when token contract does not match
    error TokenContractNotMatching(address expected, address actual);

    /// @notice Error thrown when token id does not match
    error TokenIdNotMatching(uint256 expected, uint256 actual);

    /// @notice Error thrown when a user does not own a given token
    error NotOwner(address tokenContract, uint256 tokenId);

    /// @notice Error when input lengths don't match
    error RefundInputLengthMismatch();

    /// @notice Error when there is no config for the runner
    error TransformRunnerConfigNotFound(uint256 transformEntity);

    /** PUBLIC */

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function startTransform(
        TransformInstanceComponentLayout memory transformInstance,
        uint256,
        TransformParams calldata params
    )
        external
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (bool needsVrf)
    {
        // Validate and burn inputs
        _validateAndBurnTransformInputs(transformInstance.account, params);
        // Set needVRF flag
        needsVrf = _needsVrf(params.transformEntity);
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function completeTransform(
        TransformInstanceComponentLayout memory transformInstance,
        uint256,
        uint256 randomWord
    )
        external
        view
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (uint16 numSuccess, uint256 nextRandomWord)
    {
        // Success by default
        numSuccess = transformInstance.count;
        nextRandomWord = randomWord;
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function isTransformAvailable(
        address account,
        TransformParams calldata params
    ) external view override returns (bool) {
        DefaultTransformRunnerConfigComponentLayout
            memory runnerConfig = _getDefaultTransformRunnerConfig(
                params.transformEntity
            );
        return _isTransformAvailable(account, params, runnerConfig);
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function isTransformCompleteable(
        TransformInstanceComponentLayout memory transformInstance
    ) external view override returns (bool) {
        DefaultTransformRunnerConfigComponentLayout
            memory runnerConfig = _getDefaultTransformRunnerConfig(
                transformInstance.transformEntity
            );

        if (
            block.timestamp - transformInstance.startTime <
            runnerConfig.completionDelaySeconds
        ) {
            return false;
        }

        return true;
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function onTransformComplete(
        TransformInstanceComponentLayout memory transformInstance,
        uint256 transformInstanceEntity,
        uint256 randomWord
    ) external override returns (uint256) {
        TransformRefundComponent refundComponent = TransformRefundComponent(
            _gameRegistry.getComponent(TRANSFORM_REFUND_COMPONENT_ID)
        );
        uint256 transformEntity = transformInstance.transformEntity;

        if (refundComponent.has(transformEntity)) {
            return
                _refundTransformInputs(
                    transformInstance,
                    transformInstanceEntity,
                    transformInstance.numSuccess,
                    randomWord
                );
        } else {
            return randomWord;
        }
    }

    /** INTERNAL */

    /**
     * Validates all inputs and burns them
     */

    function _validateAndBurnTransformInputs(
        address account,
        TransformParams calldata params
    ) internal {
        TransformInputComponentLayout
            memory transformDefInputs = _getTransformInputs(
                params.transformEntity
            );

        // Error if we're missing inputs
        if (transformDefInputs.inputType.length == 0) {
            revert MissingInputsOrOutputs();
        }

        // Make sure we have the right number of inputs from the caller
        if (params.inputs.length != transformDefInputs.inputType.length) {
            revert InputLengthMismatch(
                transformDefInputs.inputType.length,
                params.inputs.length
            );
        }

        // Verify that the params have inputs that meet the transform requirements
        ILootSystemV2.LootType defTokenType;
        uint256 defTokenId;
        address defTokenContract;
        uint256 defAmount;
        ILootSystemV2.Loot memory input;
        uint256 inputLootId;
        address inputTokenContract;

        for (uint8 idx; idx < transformDefInputs.inputType.length; ++idx) {
            defTokenType = ILootSystemV2.LootType(
                transformDefInputs.inputType[idx]
            );
            (defTokenContract, defTokenId) = EntityLibrary.entityToToken(
                transformDefInputs.inputEntity[idx]
            );
            defAmount = transformDefInputs.amount[idx];

            input = params.inputs[idx];

            // Make sure that token type matches between definition and id
            if (input.lootType != defTokenType) {
                revert TokenTypeNotMatching(defTokenType, input.lootType);
            }

            (inputTokenContract, inputLootId) = EntityLibrary.entityToToken(
                input.lootEntity
            );

            // Make sure a specific token contract is matching if specified
            if (
                defTokenContract != address(0) &&
                defTokenContract != inputTokenContract
            ) {
                revert TokenContractNotMatching(
                    defTokenContract,
                    inputTokenContract
                );
            }

            // Make sure token id is matching if specified
            if (defTokenId != 0 && defTokenId != inputLootId) {
                revert TokenIdNotMatching(defTokenId, inputLootId);
            }

            // Burn ERC20 and ERC1155 inputs
            if (defTokenType == ILootSystemV2.LootType.ERC20) {
                if (
                    inputTokenContract == address(0) ||
                    input.amount == 0 ||
                    inputLootId != 0
                ) {
                    revert InvalidERC20Input();
                }

                // Burn ERC20 immediately, will be refunded if not consumable later
                IGameCurrency(inputTokenContract).burn(
                    account,
                    defAmount * params.count
                );
            } else if (defTokenType == ILootSystemV2.LootType.ERC1155) {
                // Burn ERC1155 inputs immediately, refund later if they don't need to be burned
                IGameItems(inputTokenContract).burn(
                    account,
                    inputLootId,
                    defAmount * params.count
                );
            } else if (defTokenType == ILootSystemV2.LootType.ERC721) {
                if (input.amount != 1) {
                    revert InvalidERC721Input();
                }

                // Validate ownership of NFT
                if (
                    IERC721(inputTokenContract).ownerOf(inputLootId) != account
                ) {
                    revert NotOwner(inputTokenContract, inputLootId);
                }
            } else if (defTokenType == ILootSystemV2.LootType.UNDEFINED) {
                revert InvalidInputTokenType();
            }
        }
    }

    function _isTransformAvailable(
        address account,
        TransformParams calldata params,
        DefaultTransformRunnerConfigComponentLayout memory runnerConfig
    ) internal view returns (bool) {
        uint256 transformEntity = params.transformEntity;

        // Make sure user hasn't max completed already
        TransformAccountDataComponentLayout
            memory accountTransformData = TransformLibrary
                .getAccountTransformData(
                    _gameRegistry,
                    account,
                    transformEntity
                );

        if (
            runnerConfig.maxCompletions > 0 &&
            (accountTransformData.numCompletions + params.count) >
            runnerConfig.maxCompletions
        ) {
            return false;
        }

        // Make sure enough time has passed before completions
        if (runnerConfig.cooldownSeconds > 0) {
            // Cannot run multiple transforms if there's a cooldown
            if (params.count > 1) {
                return false;
            }

            // make sure no transforms are currently pending
            if (accountTransformData.numPending > 0) {
                return false;
            }

            // Make sure cooldown has passed
            if (
                accountTransformData.lastCompletionTime +
                    runnerConfig.cooldownSeconds >
                block.timestamp
            ) {
                return false;
            }
        }

        return true;
    }

    function _getDefaultTransformRunnerConfig(
        uint256 transformEntity
    )
        internal
        view
        returns (DefaultTransformRunnerConfigComponentLayout memory)
    {
        DefaultTransformRunnerConfigComponent runnerConfigComponent = DefaultTransformRunnerConfigComponent(
                _gameRegistry.getComponent(
                    DEFAULT_TRANSFORM_RUNNER_CONFIG_COMPONENT_ID
                )
            );

        if (!runnerConfigComponent.has(transformEntity)) {
            revert TransformRunnerConfigNotFound(transformEntity);
        }

        return runnerConfigComponent.getLayoutValue(transformEntity);
    }

    /**
     * Checks if the transform requires VRF
     *
     * @param transformEntity Transform to check to see for VRF
     *
     * @return bool whether or not the transform requires VRF
     */
    function _needsVrf(uint256 transformEntity) internal view returns (bool) {
        TransformRefundComponent refundComponent = TransformRefundComponent(
            _gameRegistry.getComponent(TRANSFORM_REFUND_COMPONENT_ID)
        );

        if (refundComponent.has(transformEntity)) {
            TransformRefundComponentLayout memory refund = refundComponent
                .getLayoutValue(transformEntity);

            TransformInputComponentLayout
                memory transformInputs = _getTransformInputs(transformEntity);

            // Make sure inputs match
            if (
                refund.successRefundProbability.length !=
                refund.failureRefundProbability.length ||
                refund.successRefundProbability.length !=
                transformInputs.inputType.length
            ) {
                revert RefundInputLengthMismatch();
            }

            for (uint256 i; i < refund.successRefundProbability.length; ++i) {
                if (
                    refund.successRefundProbability[i] < PERCENTAGE_RANGE &&
                    refund.successRefundProbability[i] != 0
                ) {
                    return true;
                }
                if (
                    refund.failureRefundProbability[i] < PERCENTAGE_RANGE &&
                    refund.failureRefundProbability[i] != 0
                ) {
                    return true;
                }
            }
        }

        return false;
    }

    /**
     * Remint/refund the inputs if they were not meant to be consumed
     *
     * @param transformInstance transform instance to unlock inputs for
     * @param numSuccess Number of successful transforms
     * @param randomWord random word
     *
     * @return updated random word
     */
    function _refundTransformInputs(
        TransformInstanceComponentLayout memory transformInstance,
        uint256 transformInstanceEntity,
        uint16 numSuccess,
        uint256 randomWord
    ) internal returns (uint256) {
        TransformInputComponentLayout
            memory transformDefInputs = _getTransformInputs(
                transformInstance.transformEntity
            );
        TransformRefundComponentLayout
            memory refundLayout = TransformRefundComponent(
                _gameRegistry.getComponent(TRANSFORM_REFUND_COMPONENT_ID)
            ).getLayoutValue(transformInstance.transformEntity);

        LootEntityArrayComponentLayout
            memory transformInstanceInputs = _getTransformInstanceInputs(
                transformInstanceEntity
            );

        uint16 numFailures = transformInstance.count - numSuccess;
        uint32 refundProbability;
        uint16 numRefunds;
        uint16 numNewRefunds;
        ILootSystemV2.LootType storedLootType;

        // Make sure everything matches up
        if (
            (refundLayout.successRefundProbability.length !=
                refundLayout.failureRefundProbability.length) ||
            (refundLayout.successRefundProbability.length !=
                transformDefInputs.inputType.length) ||
            (refundLayout.successRefundProbability.length !=
                transformInstanceInputs.lootType.length)
        ) {
            revert RefundInputLengthMismatch();
        }

        // Unlock inputs, grant XP, and potentially burn inputs
        for (uint256 idx; idx < transformDefInputs.inputType.length; ++idx) {
            numRefunds = 0;

            // Refund based on token type (ERC20 or ERC1155 only)
            storedLootType = ILootSystemV2.LootType(
                transformInstanceInputs.lootType[idx]
            );

            if (
                storedLootType != ILootSystemV2.LootType.ERC20 &&
                storedLootType != ILootSystemV2.LootType.ERC1155
            ) {
                continue;
            }

            // Handle success refunds
            refundProbability = refundLayout.successRefundProbability[idx];

            if (refundProbability >= PERCENTAGE_RANGE) {
                numRefunds += numSuccess;
            } else if (refundProbability == 0) {
                // No refunds
            } else {
                (numNewRefunds, randomWord) = RandomLibrary
                    .weightedCoinFlipBatch(
                        randomWord,
                        refundProbability,
                        numSuccess
                    );
                numRefunds += numNewRefunds;
            }

            // Handle failures refunds
            refundProbability = refundLayout.failureRefundProbability[idx];

            if (refundProbability >= PERCENTAGE_RANGE) {
                numRefunds += numFailures;
            } else if (refundProbability == 0) {
                // No refunds
            } else {
                (numNewRefunds, randomWord) = RandomLibrary
                    .weightedCoinFlipBatch(
                        randomWord,
                        refundProbability,
                        numFailures
                    );
                numRefunds += numNewRefunds;
            }

            // if we have any refunds, mint them back to the user
            if (numRefunds > 0) {
                _mintRefund(
                    transformInstance.account,
                    storedLootType,
                    transformInstanceInputs.lootEntity[idx],
                    transformDefInputs.amount[idx] * numRefunds
                );
            }
        }

        return randomWord;
    }

    function _mintRefund(
        address account,
        ILootSystemV2.LootType lootType,
        uint256 lootEntity,
        uint256 amount
    ) internal {
        (address tokenContract, uint256 tokenId) = EntityLibrary.entityToToken(
            lootEntity
        );

        if (lootType == ILootSystemV2.LootType.ERC20) {
            IGameCurrency(tokenContract).mint(account, amount);
        } else if (lootType == ILootSystemV2.LootType.ERC1155) {
            IGameItems(tokenContract).mint(account, tokenId, amount);
        }
    }
}
