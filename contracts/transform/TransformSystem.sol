// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import {RandomLibrary} from "../libraries/RandomLibrary.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {TransformLibrary} from "./TransformLibrary.sol";

import {RANDOMIZER_ROLE, GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";

import {ILootSystemV2, ID as LOOT_SYSTEM_ID} from "../loot/ILootSystemV2.sol";
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

import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";

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

    /// @notice Error thrown when a transform is not available to a given account
    error TransformNotAvailable(address account, uint256 transformEntity);

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
        TransformInstanceComponentLayout
            memory transformInstance = _getTransformInstance(
                transformInstanceEntity
            );

        address account = _getPlayerAccount(_msgSender());

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
     * Finishes transform with randomness
     */
    function fulfillRandomWordsCallback(
        uint256 requestId,
        uint256[] memory randomWords
    ) external override onlyRole(RANDOMIZER_ROLE) {
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
            uint256 randomWord = randomWords[0];

            for (uint256 idx; idx < transformRunners.length; ++idx) {
                (newNumSuccess, randomWord) = transformRunners[idx]
                    .completeTransform(
                        transformInstance,
                        transformInstanceEntity,
                        randomWord
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
                randomWord,
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

        for (uint256 idx; idx < transformRunners.length; ++idx) {
            needsVrf =
                transformRunners[idx].startTransform(
                    transformInstance,
                    transformInstanceEntity,
                    params
                ) ||
                needsVrf;
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
            TransformInstanceComponent(
                _gameRegistry.getComponent(TRANSFORM_INSTANCE_COMPONENT_ID)
            ).setLayoutValue(transformInstanceEntity, transformInstance);
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
            uint256 requestId = _requestRandomWords(1);
            _vrfRequests[requestId] = VRFRequest({
                account: account,
                transformInstanceEntity: transformInstanceEntity
            });
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

        accountTransformData.numPending -= transformInstance.count;
        accountTransformData.numCompletions += numSuccess;
        accountTransformData.numFailed += (transformInstance.count -
            numSuccess);

        // Update transform instance
        transformInstance.numSuccess = numSuccess;
        transformInstance.status = uint8(TransformInstanceStatus.COMPLETED);

        // Grant loot if we have any successful transforms
        if (numSuccess > 0) {
            address lootEntityArrayComponentAddress = _gameRegistry
                .getComponent(LOOT_ENTITY_ARRAY_COMPONENT_ID);
            ILootSystemV2.Loot[] memory loots = LootArrayComponentLibrary
                .convertLootEntityArrayToLoot(
                    lootEntityArrayComponentAddress,
                    transformEntity
                );

            ILootSystemV2 lootSystem = ILootSystemV2(
                _gameRegistry.getSystem(LOOT_SYSTEM_ID)
            );

            if (nextRandomWord > 0) {
                for (uint8 grantIdx; grantIdx < numSuccess; grantIdx++) {
                    nextRandomWord = RandomLibrary.generateNextRandomWord(
                        nextRandomWord
                    );
                    lootSystem.grantLootWithRandomWord(
                        account,
                        loots,
                        nextRandomWord
                    );
                }
            } else {
                // No randomness, simply grant the loot
                lootSystem.batchGrantLootWithoutRandomness(
                    account,
                    loots,
                    numSuccess
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

        return true;
    }

    /** @return Get the transform inputs from the transform entity */
    function _getTransformInputs(
        uint256 transformEntity
    ) internal view returns (TransformInputComponentLayout memory) {
        // Get the transform inputs from the transform entity
        TransformInputComponent transformInputComponent = TransformInputComponent(
                _gameRegistry.getComponent(TRANSFORM_INPUT_COMPONENT_ID)
            );
        return transformInputComponent.getLayoutValue(transformEntity);
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
