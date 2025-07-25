// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {GameRegistryLibrary} from "../libraries/GameRegistryLibrary.sol";
import {RandomLibrary} from "../libraries/RandomLibrary.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {TransformLibrary} from "./TransformLibrary.sol";

import {VRF_SYSTEM_ROLE, GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";

import {ILootSystemV2, ID as LOOT_SYSTEM_ID} from "../loot/ILootSystemV2.sol";
import {IGameItems} from "../tokens/gameitems/IGameItems.sol";
import {IGameCurrency} from "../tokens/IGameCurrency.sol";
import {ID} from "./ITransformSystem.sol";
import {TransformAccountDataComponent, Layout as TransformAccountDataComponentLayout, ID as TRANSFORM_ACCOUNT_DATA_COMPONENT_ID} from "../generated/components/TransformAccountDataComponent.sol";
import {TransformInstanceComponent, Layout as TransformInstanceComponentLayout, ID as TRANSFORM_INSTANCE_COMPONENT_ID} from "../generated/components/TransformInstanceComponent.sol";
import {TransformInputComponent, Layout as TransformInputComponentLayout, ID as TRANSFORM_INPUT_COMPONENT_ID} from "../generated/components/TransformInputComponent.sol";
import {PendingTransformInstancesComponent, Layout as PendingTransformInstancesComponentLayout, ID as PENDING_TRANSFORM_INSTANCES_COMPONENT_ID} from "../generated/components/PendingTransformInstancesComponent.sol";
import {LootEntityArrayComponent, Layout as LootEntityArrayComponentLayout, ID as LOOT_ENTITY_ARRAY_COMPONENT_ID} from "../generated/components/LootEntityArrayComponent.sol";
import {ITransformRunnerSystem, TransformParams} from "./ITransformRunnerSystem.sol";
import {GUIDLibrary} from "../core/GUIDLibrary.sol";
import {LootArrayComponentLibrary} from "../loot/LootArrayComponentLibrary.sol";
import {TransformRunnerComponent, Layout as TransformRunnerComponentLayout, ID as TRANSFORM_RUNNER_COMPONENT_ID} from "../generated/components/TransformRunnerComponent.sol";
import {ID as TIME_RANGE_COMPONENT_ID} from "../generated/components/TimeRangeComponent.sol";
import {EnabledComponent, Layout as EnabledComponentLayout, ID as ENABLED_COMPONENT_ID} from "../generated/components/EnabledComponent.sol";
import {TimeRangeLibrary} from "../core/TimeRangeLibrary.sol";
import {IAccountXpSystem, ID as ACCOUNT_XP_SYSTEM_ID} from "../trade/IAccountXpSystem.sol";
import {ID as ACCOUNT_SKILLS_XP_GRANTED_ID} from "../generated/components/AccountSkillsXpGrantedComponent.sol";
import {ID as ACCOUNT_SKILL_REQUIREMENTS_ID} from "../generated/components/AccountSkillRequirementsComponent.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {ValidatorTransformComponent, ID as VALIDATOR_TRANSFORM_COMPONENT_ID} from "../generated/components/ValidatorTransformComponent.sol";
import {ISubscriptionSystem, ID as SUBSCRIPTION_SYSTEM_ID, VIP_SUBSCRIPTION_TYPE} from "../subscription/ISubscriptionSystem.sol";
import {VipLootEntityReferenceComponent, ID as VIP_LOOT_ENTITY_REFERENCE_COMPONENT_ID} from "../generated/components/VipLootEntityReferenceComponent.sol";

// Transform Validator Role
bytes32 constant TRANSFORM_VALIDATOR_ROLE = keccak256(
    "TRANSFORM_VALIDATOR_ROLE"
);

uint256 constant NULL_LOOT_ENTITY = uint256(
    keccak256("game.piratenation.global.null_loot_entity")
);

contract TransformSystem is GameRegistryConsumerUpgradeable {
    // Struct to track and respond to VRF requests
    struct VRFRequest {
        // Account the request is for
        address account;
        // Transform instance entity for this request
        uint256 transformInstanceEntity;
    }

    // Status of a transform instance
    enum TransformInstanceStatus {
        UNDEFINED,
        STARTED,
        WAITING_FOR_VRF,
        COMPLETED
    }

    /** MEMBERS */

    /// @notice Mapping to track VRF requests
    mapping(uint256 => VRFRequest) private _vrfRequests;

    /** ERRORS */

    /// @notice Error thrown when an invalid runner is specified
    error InvalidRunner(uint256 runnerEntity);

    /// @notice Error thrown when no runners are specified
    error NoTransformRunners(uint256 transformEntity);

    /// @notice Error thrown when missing inputs or outputs for a transform
    error MissingInputsOrOutputs();

    /// @notice Error thrown when a transform input token type is invalid
    error InvalidInputTokenType();

    /// @notice Error thrown when an ERC20 input is invalid
    error InvalidERC20Input();

    /// @notice Error thrown when an ERC721 input is invalid
    error InvalidERC721Input();

    /// @notice Error thrown when input length does not match transform definition
    error InputLengthMismatch(uint256 expected, uint256 actual);

    /// @notice Error thrown when a transform is not available to a given account
    error TransformNotAvailable(address account, uint256 transformEntity);

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

    /// @notice Error thrown when a VRF transform is completed without a valid random word
    error InvalidRandomWord();

    /// @notice Error thrown when transform is not completeable
    error TransformNotCompleteable(uint256 transformInstanceEntity);

    /// @notice Error thrown when caller is not the owner of the transform instance
    error CallerNotOwner(address caller, address owner);

    /// @notice Error thrown when num success is invalid
    error InvalidNumSuccess(
        uint256 transformInstanceEntity,
        uint16 numSuccess,
        uint16 maxSuccess
    );

    /// @notice Zero param count
    error ZeroParamCount();

    /// @notice Empty Transform Array
    error EmptyTransformArray();

    /// @notice Not a Validator-only transform
    error ValidatorOnlyTransform();

    /** PUBLIC **/

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * Whether or not a given transform is available to the given player
     *
     * @param account Account to check if transform is available for
     * @param params params to use to run the transform
     *
     * @return Whether or not the transform is available to the given account
     */
    function isTransformAvailable(
        address account,
        TransformParams calldata params
    ) external view returns (bool) {
        return
            _isTransformAvailable(
                account,
                _getTransformRunners(params.transformEntity),
                params
            );
    }

    /**
     * Starts a transform for a user using the validator role
     *
     * @param params Transform parameters for the transform (See struct definition)
     * @param account Account to start the transform for
     *
     * @return returns transformInstanceEntity that was created to track this transform run
     */
    function startTransformUsingValidator(
        TransformParams calldata params,
        address account
    )
        external
        nonReentrant
        whenNotPaused
        onlyRole(TRANSFORM_VALIDATOR_ROLE)
        returns (uint256)
    {
        if (
            ValidatorTransformComponent(
                _gameRegistry.getComponent(VALIDATOR_TRANSFORM_COMPONENT_ID)
            ).getValue(params.transformEntity) == false
        ) {
            revert ValidatorOnlyTransform();
        }
        return _startTransform(params, account);
    }

    /**
     * Completes a transform for a user using the validator role
     *
     * @param transformInstanceEntity Transform instance to complete
     * @param account Account to complete the transform for
     */
    function completeTransformUsingValidator(
        uint256 transformInstanceEntity,
        address account
    ) external nonReentrant whenNotPaused onlyRole(TRANSFORM_VALIDATOR_ROLE) {
        TransformInstanceComponentLayout
            memory transformInstance = _getTransformInstance(
                transformInstanceEntity
            );
        if (
            ValidatorTransformComponent(
                _gameRegistry.getComponent(VALIDATOR_TRANSFORM_COMPONENT_ID)
            ).getValue(transformInstance.transformEntity) == false
        ) {
            revert ValidatorOnlyTransform();
        }
        // Make sure current account is the owner of the transform instance
        if (account != transformInstance.account) {
            revert CallerNotOwner(account, transformInstance.account);
        }

        ITransformRunnerSystem[] memory transformRunners = _getTransformRunners(
            transformInstance.transformEntity
        );

        if (!_isCompleteable(account, transformRunners, transformInstance)) {
            revert TransformNotCompleteable(transformInstanceEntity);
        }

        _completeTransform(
            account,
            transformRunners,
            transformInstance,
            transformInstanceEntity
        );
    }

    /**
     * Starts a transform for a user with a given account
     *
     * @param params Transform parameters for the transform (See struct definition)
     * @param account Account to start the transform for
     * @return returns transformInstanceEntity that was created to track this transform run
     */
    function startTransformWithAccount(
        TransformParams calldata params,
        address account
    )
        external
        nonReentrant
        whenNotPaused
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (uint256)
    {
        if (
            ValidatorTransformComponent(
                _gameRegistry.getComponent(VALIDATOR_TRANSFORM_COMPONENT_ID)
            ).getValue(params.transformEntity) == true
        ) {
            revert ValidatorOnlyTransform();
        }
        return _startTransform(params, account);
    }

    /**
     * Starts a transform for a user
     *
     * @param params Transform parameters for the transform (See struct definition)
     *
     * @return returns transformInstanceEntity that was created to track this transform run
     */
    function startTransform(
        TransformParams calldata params
    ) external nonReentrant whenNotPaused returns (uint256) {
        if (
            ValidatorTransformComponent(
                _gameRegistry.getComponent(VALIDATOR_TRANSFORM_COMPONENT_ID)
            ).getValue(params.transformEntity) == true
        ) {
            revert ValidatorOnlyTransform();
        }
        address account = _getPlayerAccount(_msgSender());
        return _startTransform(params, account);
    }

    /**
     * Complete a transform for a user with a given account
     *
     * @param transformInstanceEntity Transform instance to complete
     * @param account Account to complete the transform for
     */
    function completeTransformWithAccount(
        uint256 transformInstanceEntity,
        address account
    ) external nonReentrant whenNotPaused onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        TransformInstanceComponentLayout
            memory transformInstance = _getTransformInstance(
                transformInstanceEntity
            );
        if (
            ValidatorTransformComponent(
                _gameRegistry.getComponent(VALIDATOR_TRANSFORM_COMPONENT_ID)
            ).getValue(transformInstance.transformEntity) == true
        ) {
            revert ValidatorOnlyTransform();
        }
        // Make sure current account is the owner of the transform instance
        if (account != transformInstance.account) {
            revert CallerNotOwner(account, transformInstance.account);
        }

        ITransformRunnerSystem[] memory transformRunners = _getTransformRunners(
            transformInstance.transformEntity
        );

        if (!_isCompleteable(account, transformRunners, transformInstance)) {
            revert TransformNotCompleteable(transformInstanceEntity);
        }

        _completeTransform(
            account,
            transformRunners,
            transformInstance,
            transformInstanceEntity
        );
    }

    /**
     * Completes the given transform instance
     * @param transformInstanceEntity Transform instance to complete
     */
    function completeTransform(
        uint256 transformInstanceEntity
    ) public nonReentrant whenNotPaused {
        address account = _getPlayerAccount(_msgSender());

        _validateAndCompleteTransformInstance(account, transformInstanceEntity);
    }

    /**
     * Completes a batch of transform instances
     * @param transformInstanceEntities Entities of the transform instances to complete
     */
    function batchCompleteTransform(
        uint256[] memory transformInstanceEntities
    ) public nonReentrant whenNotPaused {
        if (transformInstanceEntities.length == 0) {
            revert EmptyTransformArray();
        }
        address account = _getPlayerAccount(_msgSender());
        for (uint256 idx; idx < transformInstanceEntities.length; ++idx) {
            _validateAndCompleteTransformInstance(
                account,
                transformInstanceEntities[idx]
            );
        }
    }

    /**
     * Finishes transform with randomness
     */
    function randomNumberCallback(
        uint256 requestId,
        uint256 randomNumber
    ) external override onlyRole(VRF_SYSTEM_ROLE) {
        VRFRequest storage request = _vrfRequests[requestId];
        address account = request.account;

        if (account != address(0)) {
            uint256 transformInstanceEntity = request.transformInstanceEntity;

            TransformInstanceComponentLayout
                memory transformInstance = _getTransformInstance(
                    transformInstanceEntity
                );

            // Get the transform runner system
            ITransformRunnerSystem[]
                memory transformRunners = _getTransformRunners(
                    transformInstance.transformEntity
                );

            uint16 numSuccess = transformInstance.count;
            uint16 newNumSuccess;

            for (uint256 idx; idx < transformRunners.length; ++idx) {
                (newNumSuccess, randomNumber) = transformRunners[idx]
                    .completeTransform(
                        transformInstance,
                        transformInstanceEntity,
                        randomNumber
                    );

                // We take the min of the num success
                numSuccess = numSuccess < newNumSuccess
                    ? numSuccess
                    : newNumSuccess;
            }

            _completeTransformInstanceAndGrantLoot(
                account,
                transformInstance,
                transformInstanceEntity,
                numSuccess,
                randomNumber,
                transformRunners
            );

            // Delete the VRF request
            delete _vrfRequests[requestId];
        }
    }

    /**
     * Checks and returns whether or not a given transform instance is completeable
     *
     * @param transformInstanceEntity Transform instance to check
     * @return  Whether or not the transform instance is completeable
     */
    function isTransformCompleteable(
        uint256 transformInstanceEntity
    ) external view returns (bool) {
        TransformInstanceComponentLayout
            memory transformInstance = _getTransformInstance(
                transformInstanceEntity
            );

        return
            _isCompleteable(
                transformInstance.account,
                _getTransformRunners(transformInstance.transformEntity),
                transformInstance
            );
    }

    /** INTERNAL **/

    function _startTransform(
        TransformParams calldata params,
        address account
    ) internal returns (uint256) {
        if (params.count == 0) {
            revert ZeroParamCount();
        }
        uint256 transformEntity = params.transformEntity;

        ITransformRunnerSystem[] memory transformRunners = _getTransformRunners(
            transformEntity
        );

        // Error if we have no runners
        if (transformRunners.length == 0) {
            revert NoTransformRunners(transformEntity);
        }

        // Verify user can start this transform and meets requirements
        if (_isTransformAvailable(account, transformRunners, params) != true) {
            revert TransformNotAvailable(account, transformEntity);
        }

        // Validate and burn inputs
        _validateAndBurnTransformInputs(account, params);

        // Create transform instance entity to track run
        uint256 transformInstanceEntity = GUIDLibrary.guidV1(
            _gameRegistry,
            "transformsystem.instance"
        );

        TransformInstanceComponentLayout
            memory transformInstance = TransformInstanceComponentLayout({
                transformEntity: transformEntity,
                account: account,
                status: uint8(TransformInstanceStatus.STARTED),
                startTime: uint32(block.timestamp),
                needsVrf: false,
                numSuccess: 0,
                count: uint16(params.count)
            });

        // Allow runner to run its checks, revert if necessary, and start the transform
        bool needsVrf;
        bool skipTransformInstance;

        for (uint256 idx; idx < transformRunners.length; ++idx) {
            bool _needsVrf;
            bool _skipTransformInstance;
            (_needsVrf, _skipTransformInstance) = transformRunners[idx]
                .startTransform(
                    transformInstance,
                    transformInstanceEntity,
                    params
                );
            // Ensure that values are not overwritten
            needsVrf = needsVrf || _needsVrf;
            skipTransformInstance =
                skipTransformInstance ||
                _skipTransformInstance;
        }

        transformInstance.needsVrf = needsVrf;

        // Track new pending instance for this account
        uint256[] memory newInstances = new uint256[](1);
        newInstances[0] = transformInstanceEntity;

        PendingTransformInstancesComponent(
            _gameRegistry.getComponent(PENDING_TRANSFORM_INSTANCES_COMPONENT_ID)
        ).append(
                EntityLibrary.addressToEntity(account),
                PendingTransformInstancesComponentLayout(newInstances)
            );

        // Set loot array component to track inputs
        LootEntityArrayComponent(
            _gameRegistry.getComponent(LOOT_ENTITY_ARRAY_COMPONENT_ID)
        ).setLayoutValue(
                transformInstanceEntity,
                LootArrayComponentLibrary.convertLootToLootEntityArray(
                    params.inputs
                )
            );

        // Update account transform data
        TransformAccountDataComponentLayout
            memory accountTransformData = TransformLibrary
                .getAccountTransformData(
                    _gameRegistry,
                    account,
                    transformEntity
                );
        accountTransformData.numPending += params.count;

        TransformAccountDataComponent(
            _gameRegistry.getComponent(TRANSFORM_ACCOUNT_DATA_COMPONENT_ID)
        ).setLayoutValue(
                TransformLibrary._getAccountTransformDataEntity(
                    account,
                    transformEntity
                ),
                accountTransformData
            );

        // If transform is completeable, complete it immediately
        if (_isCompleteable(account, transformRunners, transformInstance)) {
            _completeTransform(
                account,
                transformRunners,
                transformInstance,
                transformInstanceEntity
            );
        } else {
            // If the transform isn't immediately completable we should save it here
            if (skipTransformInstance == false) {
                TransformInstanceComponent(
                    _gameRegistry.getComponent(TRANSFORM_INSTANCE_COMPONENT_ID)
                ).setLayoutValue(transformInstanceEntity, transformInstance);
            }
        }

        return transformInstanceEntity;
    }

    function _isCompleteable(
        address,
        ITransformRunnerSystem[] memory runners,
        TransformInstanceComponentLayout memory transformInstance
    ) internal view returns (bool) {
        if (
            transformInstance.status != uint8(TransformInstanceStatus.STARTED)
        ) {
            return false;
        }

        for (uint256 idx; idx < runners.length; ++idx) {
            if (
                runners[idx].isTransformCompleteable(transformInstance) == false
            ) {
                return false;
            }
        }

        return true;
    }

    function _completeTransform(
        address account,
        ITransformRunnerSystem[] memory transformRunners,
        TransformInstanceComponentLayout memory transformInstance,
        uint256 transformInstanceEntity
    ) internal {
        // See if loot is needed
        address lootEntityArrayComponentAddress = _gameRegistry.getComponent(
            LOOT_ENTITY_ARRAY_COMPONENT_ID
        );
        ILootSystemV2.Loot[] memory loots = LootArrayComponentLibrary
            .convertLootEntityArrayToLoot(
                lootEntityArrayComponentAddress,
                transformInstance.transformEntity
            );
        // Grant VIP loot if the user has a VIP subscription and a VIP loot entity is set
        uint256 vipLootEntity = VipLootEntityReferenceComponent(
            _gameRegistry.getComponent(VIP_LOOT_ENTITY_REFERENCE_COMPONENT_ID)
        ).getValue(transformInstance.transformEntity);
        if (vipLootEntity != 0 && vipLootEntity != NULL_LOOT_ENTITY) {
            if (
                ISubscriptionSystem(
                    _gameRegistry.getSystem(SUBSCRIPTION_SYSTEM_ID)
                ).checkHasActiveSubscription(VIP_SUBSCRIPTION_TYPE, account)
            ) {
                loots = LootArrayComponentLibrary.convertLootEntityArrayToLoot(
                    lootEntityArrayComponentAddress,
                    vipLootEntity
                );
            }
        }
        bool lootNeedsVrf = ILootSystemV2(
            _gameRegistry.getSystem(LOOT_SYSTEM_ID)
        ).validateLoots(loots);
        if (transformInstance.needsVrf == false && lootNeedsVrf == false) {
            uint16 numSuccess = transformInstance.count;
            uint16 newNumSuccess;

            for (uint256 idx; idx < transformRunners.length; ++idx) {
                // Complete the transform immediately, no random words (0)
                (newNumSuccess, ) = transformRunners[idx].completeTransform(
                    transformInstance,
                    transformInstanceEntity,
                    0
                );

                // We take the min of the num success
                numSuccess = numSuccess < newNumSuccess
                    ? numSuccess
                    : newNumSuccess;
            }

            _completeTransformInstanceAndGrantLoot(
                account,
                transformInstance,
                transformInstanceEntity,
                numSuccess,
                0,
                transformRunners
            );
        } else {
            // Set the status to waiting for VRF
            transformInstance.status = uint8(
                TransformInstanceStatus.WAITING_FOR_VRF
            );

            // Make sure needs VRF flag is set
            transformInstance.needsVrf = true;

            // Save the transform instance
            TransformInstanceComponent(
                _gameRegistry.getComponent(TRANSFORM_INSTANCE_COMPONENT_ID)
            ).setLayoutValue(transformInstanceEntity, transformInstance);

            // Request random words from the randomizer and store the request
            uint256 requestId = _requestRandomNumber(0);
            _vrfRequests[requestId] = VRFRequest({
                account: account,
                transformInstanceEntity: transformInstanceEntity
            });
        }
    }

    /**
     * Validates and completes a transform instance
     */
    function _validateAndCompleteTransformInstance(
        address account,
        uint256 transformInstanceEntity
    ) internal {
        TransformInstanceComponentLayout
            memory transformInstance = _getTransformInstance(
                transformInstanceEntity
            );
        if (
            ValidatorTransformComponent(
                _gameRegistry.getComponent(VALIDATOR_TRANSFORM_COMPONENT_ID)
            ).getValue(transformInstance.transformEntity) == true
        ) {
            revert ValidatorOnlyTransform();
        }

        // Make sure current account is the owner of the transform instance
        if (account != transformInstance.account) {
            revert CallerNotOwner(account, transformInstance.account);
        }

        ITransformRunnerSystem[] memory transformRunners = _getTransformRunners(
            transformInstance.transformEntity
        );

        if (!_isCompleteable(account, transformRunners, transformInstance)) {
            revert TransformNotCompleteable(transformInstanceEntity);
        }

        _completeTransform(
            account,
            transformRunners,
            transformInstance,
            transformInstanceEntity
        );
    }

    /**
     * Validates all inputs and burns them
     */

    function _validateAndBurnTransformInputs(
        address account,
        TransformParams calldata params
    ) internal {
        TransformInputComponentLayout
            memory transformDefInputs = TransformLibrary
                .getTransformInputsForAccount(
                    _gameRegistry,
                    account,
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

    /**
     * Wraps up a transform by updating the transform instance and granting any loot
     *
     * @param account Account of the transform to be completed
     * @param transformInstanceEntity Instance being completed
     * @param numSuccess Number of successful transforms
     * @param nextRandomWord random word
     *
     */
    function _completeTransformInstanceAndGrantLoot(
        address account,
        TransformInstanceComponentLayout memory transformInstance,
        uint256 transformInstanceEntity,
        uint16 numSuccess,
        uint256 nextRandomWord,
        ITransformRunnerSystem[] memory transformRunners
    ) internal {
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        uint256 transformEntity = transformInstance.transformEntity;

        if (transformInstance.needsVrf && nextRandomWord == 0) {
            revert InvalidRandomWord();
        }

        if (numSuccess > transformInstance.count) {
            revert InvalidNumSuccess(
                transformInstanceEntity,
                numSuccess,
                transformInstance.count
            );
        }

        // Update account data
        TransformAccountDataComponentLayout
            memory accountTransformData = TransformLibrary
                .getAccountTransformData(
                    _gameRegistry,
                    account,
                    transformEntity
                );

        uint32 numFailures = transformInstance.count - numSuccess;
        accountTransformData.numPending -= transformInstance.count;
        accountTransformData.numCompletions += numSuccess;
        accountTransformData.numFailed += numFailures;

        // Update transform instance
        transformInstance.numSuccess = numSuccess;
        transformInstance.status = uint8(TransformInstanceStatus.COMPLETED);

        // Grant loot if we have any successful transforms
        if (numSuccess > 0) {
            ILootSystemV2.Loot[] memory loots = LootArrayComponentLibrary
                .convertLootEntityArrayToLoot(
                    _gameRegistry.getComponent(LOOT_ENTITY_ARRAY_COMPONENT_ID),
                    transformEntity
                );
            // Grant VIP loot if the user has a VIP subscription and a VIP loot entity is set
            uint256 vipLootEntity = VipLootEntityReferenceComponent(
                _gameRegistry.getComponent(
                    VIP_LOOT_ENTITY_REFERENCE_COMPONENT_ID
                )
            ).getValue(transformEntity);
            if (vipLootEntity != 0 && vipLootEntity != NULL_LOOT_ENTITY) {
                if (
                    ISubscriptionSystem(
                        _gameRegistry.getSystem(SUBSCRIPTION_SYSTEM_ID)
                    ).checkHasActiveSubscription(VIP_SUBSCRIPTION_TYPE, account)
                ) {
                    loots = LootArrayComponentLibrary
                        .convertLootEntityArrayToLoot(
                            _gameRegistry.getComponent(
                                LOOT_ENTITY_ARRAY_COMPONENT_ID
                            ),
                            vipLootEntity
                        );
                }
            }

            if (loots.length > 0) {
                if (nextRandomWord > 0) {
                    for (uint8 grantIdx; grantIdx < numSuccess; grantIdx++) {
                        nextRandomWord = RandomLibrary.generateNextRandomWord(
                            nextRandomWord
                        );
                        ILootSystemV2(_gameRegistry.getSystem(LOOT_SYSTEM_ID))
                            .grantLootWithRandomWord(
                                account,
                                loots,
                                nextRandomWord
                            );
                    }
                } else {
                    // No randomness, simply grant the loot
                    ILootSystemV2(_gameRegistry.getSystem(LOOT_SYSTEM_ID))
                        .batchGrantLootWithoutRandomness(
                            account,
                            loots,
                            numSuccess
                        );
                }
            }

            if (
                _gameRegistry.getEntityHasComponent(
                    transformEntity,
                    ACCOUNT_SKILLS_XP_GRANTED_ID
                )
            ) {
                IAccountXpSystem(_gameRegistry.getSystem(ACCOUNT_XP_SYSTEM_ID))
                    .grantAccountSkillsXp(
                        accountEntity,
                        transformEntity,
                        numSuccess,
                        numFailures
                    );
            }

            // Update account and transform instance
            accountTransformData.lastCompletionTime = uint32(block.timestamp);
        }

        // Update account data
        TransformAccountDataComponent(
            _gameRegistry.getComponent(TRANSFORM_ACCOUNT_DATA_COMPONENT_ID)
        ).setLayoutValue(
                TransformLibrary._getAccountTransformDataEntity(
                    account,
                    transformEntity
                ),
                accountTransformData
            );

        // Update instance
        TransformInstanceComponent transformInstanceComponent = TransformInstanceComponent(
                _gameRegistry.getComponent(TRANSFORM_INSTANCE_COMPONENT_ID)
            );
        transformInstanceComponent.setLayoutValue(
            transformInstanceEntity,
            transformInstance
        );

        // Remove from pending instances array
        PendingTransformInstancesComponent pendingTransformInstancesComponent = PendingTransformInstancesComponent(
                _gameRegistry.getComponent(
                    PENDING_TRANSFORM_INSTANCES_COMPONENT_ID
                )
            );
        uint256[] memory pendingTransforms = pendingTransformInstancesComponent
            .getValue(accountEntity);

        for (uint256 idx; idx < pendingTransforms.length; ++idx) {
            if (pendingTransforms[idx] == transformInstanceEntity) {
                pendingTransformInstancesComponent.removeValueAtIndex(
                    accountEntity,
                    idx
                );
                break;
            }
        }

        // Run post complete callback
        for (uint256 idx; idx < transformRunners.length; ++idx) {
            transformRunners[idx].onTransformComplete(
                transformInstance,
                transformInstanceEntity,
                nextRandomWord
            );
        }
    }

    /**
     * checks if a transform is available
     *
     * @param account Account to be checked
     * @param transformRunners transform runners to be checked
     * @param params params used to start the transform
     *
     * @return bool whether or not the transform is available to be run
     */
    function _isTransformAvailable(
        address account,
        ITransformRunnerSystem[] memory transformRunners,
        TransformParams calldata params
    ) internal view returns (bool) {
        if (transformRunners.length == 0) {
            return false;
        }
        uint256 transformEntity = params.transformEntity;

        // Make sure transform is enabled
        EnabledComponent enabledComponent = EnabledComponent(
            _gameRegistry.getComponent(ENABLED_COMPONENT_ID)
        );

        if (enabledComponent.getValue(transformEntity) == false) {
            return false;
        }

        // Make sure transform is within timerange if one is set
        if (
            TimeRangeLibrary.checkWithinOptionalTimeRange(
                _gameRegistry.getComponent(TIME_RANGE_COMPONENT_ID),
                transformEntity
            ) == false
        ) {
            return false;
        }

        for (uint256 idx; idx < transformRunners.length; ++idx) {
            if (
                transformRunners[idx].isTransformAvailable(account, params) ==
                false
            ) {
                return false;
            }
        }

        if (
            _gameRegistry.getEntityHasComponent(
                transformEntity,
                ACCOUNT_SKILL_REQUIREMENTS_ID
            )
        ) {
            if (
                !IAccountXpSystem(_gameRegistry.getSystem(ACCOUNT_XP_SYSTEM_ID))
                    .hasRequiredSkills(
                        EntityLibrary.addressToEntity(account),
                        transformEntity
                    )
            ) {
                return false;
            }
        }

        return true;
    }

    function _getTransformRunners(
        uint256 transformEntity
    ) internal view returns (ITransformRunnerSystem[] memory) {
        uint256[] memory runnerEntities = TransformRunnerComponent(
            _gameRegistry.getComponent(TRANSFORM_RUNNER_COMPONENT_ID)
        ).getLayoutValue(transformEntity).transformRunnerEntities;

        ITransformRunnerSystem[] memory runners = new ITransformRunnerSystem[](
            runnerEntities.length
        );

        uint256 runnerEntity;
        for (uint256 idx; idx < runnerEntities.length; ++idx) {
            runnerEntity = runnerEntities[idx];

            if (runnerEntity == 0) {
                revert InvalidRunner(runnerEntity);
            }

            address transformRunnerAddress = _gameRegistry.getSystem(
                runnerEntity
            );

            if (transformRunnerAddress == address(0)) {
                revert InvalidRunner(runnerEntity);
            }

            runners[idx] = ITransformRunnerSystem(transformRunnerAddress);
        }

        return runners;
    }

    /** @return Transform instance component data */
    function _getTransformInstance(
        uint256 transformInstanceEntity
    ) internal view returns (TransformInstanceComponentLayout memory) {
        // Get transform instance component
        TransformInstanceComponent transformInstanceComponent = TransformInstanceComponent(
                _gameRegistry.getComponent(TRANSFORM_INSTANCE_COMPONENT_ID)
            );
        return
            transformInstanceComponent.getLayoutValue(transformInstanceEntity);
    }

    /** @return Inputs for the transform instance. These were stored when the instance was created */
    function _getTransformInstanceInputs(
        uint256 transformInstanceEntity
    ) internal view returns (LootEntityArrayComponentLayout memory) {
        // Get transform instance component
        LootEntityArrayComponent lootArrayComponent = LootEntityArrayComponent(
            _gameRegistry.getComponent(LOOT_ENTITY_ARRAY_COMPONENT_ID)
        );
        LootEntityArrayComponentLayout memory inputs = lootArrayComponent
            .getLayoutValue(transformInstanceEntity);

        return inputs;
    }
}
