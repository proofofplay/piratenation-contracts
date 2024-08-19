// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../GameRegistryConsumerUpgradeable.sol";

import {EntityLibrary} from "../core/EntityLibrary.sol";
import {Uint256Component, ID as UINT256_COMPONENT_ID} from "../generated/components/Uint256Component.sol";

import {ILootSystemV2, ID as LOOT_SYSTEM_V2_ID} from "../loot/ILootSystemV2.sol";
import {RANDOMIZER_ROLE} from "../Constants.sol";
import {EndBattleParams, IDungeonBattleSystemV2, ID as DUNGEON_BATTLE_SYSTEM_ID} from "./IDungeonBattleSystemV2.sol";
import {IDungeonProgressSystem, ID as DUNGEON_PROGRESS_SYSTEM_ID, DungeonNodeProgressState} from "./IDungeonProgressSystem.sol";
import {StartAndEndDungeonBattleParams, StartAndEndValidatedDungeonBattleParams, StartDungeonBattleParams, EndDungeonBattleParams, IDungeonSystemV3, DungeonMap, DungeonNode, DungeonTrigger} from "./IDungeonSystemV3.sol";
import {AccountXpGrantedComponent, Layout as AccountXpGrantedComponentStruct, ID as ACCOUNT_XP_GRANTED_COMPONENT_ID} from "../generated/components/AccountXpGrantedComponent.sol";
import {CombatMapComponent, ID as CombatMapComponentId, Layout as CombatMapComponentLayout} from "../generated/components/CombatMapComponent.sol";
import {CombatEncounterComponent, ID as CombatEncounterComponentId, Layout as CombatEncounterComponentLayout} from "../generated/components/CombatEncounterComponent.sol";
import {CreatedTimestampComponent, ID as CREATED_TIMESTAMP_COMPONENT_ID} from "../generated/components/CreatedTimestampComponent.sol";
import {GauntletScheduleComponent, ID as GauntletScheduleComponentId, Layout as GauntletScheduleComponentLayout, ID as GAUNTLET_SCHEDULE_ENTITY} from "../generated/components/GauntletScheduleComponent.sol";
import {TransferStatusComponent, ID as TRANSFER_STATUS_COMPONENT_ID} from "../generated/components/TransferStatusComponent.sol";
import {TransformInputComponent, ID as TRANSFORM_INPUT_COMPONENT_ID} from "../generated/components/TransformInputComponent.sol";
import {CountingSystem, ID as COUNTING_SYSTEM} from "../counting/CountingSystem.sol";
import {IAccountXpSystem, ID as ACCOUNT_XP_SYSTEM_ID} from "../trade/IAccountXpSystem.sol";
import {ID as LOOT_ENTITY_ARRAY_COMPONENT_ID} from "../generated/components/LootEntityArrayComponent.sol";
import {LootArrayComponentLibrary} from "../loot/LootArrayComponentLibrary.sol";
import {TransferLibrary, TransferStatus} from "../trade/TransferLibrary.sol";

import {BanComponent, ID as BAN_COMPONENT_ID} from "../generated/components/BanComponent.sol";
import {Banned} from "../ban/BanSystem.sol";

import {BattleValidationComponent, ID as BATTLE_VALIDATION_COMPONENT_ID} from "../generated/components/BattleValidationComponent.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.dungeonsystem.v3"));

// The margin of time (in seconds) the user has to complete a dungeon after
// starting it and after the dungeon's end point as past.
uint256 constant DAILY_DUNGEONS_EXTRA_TIME_TO_COMPLETE = uint256(
    keccak256("game.piratenation.global.daily_dungeons.extra_time_to_complete")
);

// Role used by battle validator endpoint
bytes32 constant BATTLE_VALIDATOR_ROLE = keccak256("BATTLE_VALIDATOR_ROLE");

// Struct to track and respond to VRF requests
struct LootRequest {
    // Account the request belongs to
    address account;
    // Battle entity the request belongs to
    uint256 battleEntity;
    // Dungeon instance the request belongs to
    uint256 scheduledStartTimestamp;
    // Map entity the request belongs to
    uint256 dungeonMapEntity;
    // Node id the request belongs to
    uint256 node;
}

/**
 * @title DungeonSystemV3
 */
contract DungeonSystemV3 is IDungeonSystemV3, GameRegistryConsumerUpgradeable {
    /** MEMBERS **/

    /// @notice Mapping to track VRF requestId ➞ LootRequest
    mapping(uint256 => LootRequest) private _vrfRequests;

    /** EVENTS **/

    /// @notice Emitted when dungeon loot is granted
    // NOTE: We're leaving this in for the Unity cutover, wil be removed in
    // the next iteration of the contracts.
    event DungeonLootGranted(
        address indexed account,
        uint256 indexed battleEntity,
        uint256 scheduledStartTimestamp,
        uint256 mapEntity,
        uint256 node
    );

    /** ERRORS **/

    error DungeonNotAvailable(uint256 scheduledStartTimestamp);
    error DungeonExpired(uint256 scheduledStartTimestamp);
    error DungeonMapAlreadyUnlockedForPlayer(
        uint256 playerDungeonTriggerEntity
    );
    error DungeonMapEntityMismatch(uint256 expected, uint256 actual);
    error DungeonMapLockedForPlayer(uint256 playerDungeonTriggerEntity);
    error DungeonMapNotFound(
        uint256 mapEntity,
        uint256 scheduledStartTimestamp
    );
    error DungeonMapNotLocked(uint256 mapEntity);
    error DungeonAlreadyCompleted(uint256 scheduledStartTimestamp);
    error DungeonNodeAlreadyCompleted(
        uint256 scheduledStartTimestamp,
        uint256 encounterEntity
    );
    error DungeonNodeOutOfOrder(
        uint256 scheduledStartTimestamp,
        uint256 encounterEntity
    );
    error DungeonNodePreviousNotCompleted(
        uint256 scheduledStartTimestamp,
        uint256 encounterEntity
    );
    error DungeonNodeNotStarted(
        uint256 scheduledStartTimestamp,
        uint256 encounterEntity
    );
    error DungeonNodeBattleEntityMismatch(
        uint256 scheduledStartTimestamp,
        uint256 encounterEntity,
        uint256 givenBattleEntity
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
     * @inheritdoc IDungeonSystemV3
     */
    function getDungeonTriggerByIndex(
        uint256 scheduleIdx
    ) external view override returns (DungeonTrigger memory) {
        return _getDungeonTrigger(scheduleIdx);
    }

    /**
     * @inheritdoc IDungeonSystemV3
     */
    function getDungeonTriggerByStartTimestamp(
        uint256 scheduledStart
    ) external view override returns (DungeonTrigger memory) {
        return _getDungeonTriggerByStartTimestamp(scheduledStart);
    }

    /**
     * @inheritdoc IDungeonSystemV3
     */
    function getDungeonMapById(
        uint256 mapEntity
    ) external view override returns (DungeonMap memory) {
        return _getDungeonMap(mapEntity);
    }

    /**
     * @inheritdoc IDungeonSystemV3
     */
    function getDungeonMapByScheduleIndex(
        uint256 scheduleIdx
    ) external view override returns (DungeonMap memory) {
        DungeonTrigger memory trigger = _getDungeonTrigger(scheduleIdx);
        return _getDungeonMap(trigger.dungeonMapEntity);
    }

    /**
     * @inheritdoc IDungeonSystemV3
     */
    function getDungeonNode(
        uint256 encounterEntity
    ) external view override returns (DungeonNode memory) {
        return _getDungeonNode(encounterEntity);
    }

    function unlockDungeonMap(
        uint256 mapEntity,
        uint256 scheduledStart
    ) external nonReentrant whenNotPaused {
        // TODO: Move to transform runner...
        address account = _getPlayerAccount(_msgSender());
        (, DungeonTrigger memory trigger) = _validateDungeonMap(
            mapEntity,
            scheduledStart
        );

        // Check that the dungeon has not yet finished
        if (trigger.endAt < block.timestamp) {
            revert DungeonExpired(scheduledStart);
        }

        // Check that dungeon map has entry fees
        TransformInputComponent transformInputComponent = _getTransformInputComponent();
        if (!transformInputComponent.has(mapEntity)) {
            revert DungeonMapNotLocked(mapEntity);
        }

        _generateTransferReceipt(
            account,
            mapEntity,
            scheduledStart,
            transformInputComponent
        );

        // Burn inputs
        LootArrayComponentLibrary.burnTransformInput(
            address(transformInputComponent),
            account,
            mapEntity
        );
    }

    /**
     * @inheritdoc IDungeonSystemV3
     */
    function startDungeonBattle(
        StartDungeonBattleParams calldata params
    ) external nonReentrant whenNotPaused returns (uint256) {
        address account = _getPlayerAccount(_msgSender());
        return _startDungeonBattle(account, params);
    }

    /**
     * @inheritdoc IDungeonSystemV3
     */
    function endDungeonBattle(
        EndDungeonBattleParams calldata params
    ) external nonReentrant whenNotPaused {
        address account = _getPlayerAccount(_msgSender());
        _endDungeonBattle(account, params);
    }

    /**
     * A single call to manage starting and ending the battle for a dungeon node.
     * @param params Data for an started and ended battle.
     */
    function startAndEndDungeonBattle(
        StartAndEndDungeonBattleParams calldata params
    ) external nonReentrant whenNotPaused {
        address account = _getPlayerAccount(_msgSender());
        _startAndEndDungeonBattle(account, params);
    }

    function _startAndEndDungeonBattle(
        address account,
        StartAndEndDungeonBattleParams calldata params
    ) private returns (uint256) {
        uint256 battleEntity = _startDungeonBattle(
            account,
            StartDungeonBattleParams({
                battleSeed: params.battleSeed,
                scheduledStart: params.scheduledStart,
                mapEntity: params.mapEntity,
                encounterEntity: params.encounterEntity,
                shipEntity: params.shipEntity,
                shipOverloads: params.shipOverloads
            })
        );
        _endDungeonBattle(
            account,
            EndDungeonBattleParams({
                battleEntity: battleEntity,
                scheduledStart: params.scheduledStart,
                mapEntity: params.mapEntity,
                encounterEntity: params.encounterEntity,
                success: params.success
            })
        );

        return battleEntity;
    }

    /**
     * Submits a dungeon battle completion with supporting data to prove the battle was valid.
     * @param params Data for an started and ended battle.
     */
    function startAndEndValidatedDungeonBattle(
        StartAndEndDungeonBattleParams calldata params,
        string calldata ipfsUrl,
        address operatorWallet
    )
        external
        nonReentrant
        whenNotPaused
        onlyRole(BATTLE_VALIDATOR_ROLE)
        returns (uint256)
    {
        address account = _getPlayerAccount(operatorWallet);

        uint256 battleEntity = _startAndEndDungeonBattle(account, params);

        BattleValidationComponent(
            _gameRegistry.getComponent(BATTLE_VALIDATION_COMPONENT_ID)
        ).setValue(battleEntity, ipfsUrl);

        return battleEntity;
    }

    /**
     * @inheritdoc GameRegistryConsumerUpgradeable
     */
    function fulfillRandomWordsCallback(
        uint256 requestId,
        uint256[] memory randomWords
    ) external override onlyRole(RANDOMIZER_ROLE) {
        LootRequest storage request = _vrfRequests[requestId];

        if (request.account != address(0)) {
            // Grant the loot.
            _grantLootComplete(
                request,
                randomWords[0],
                _getDungeonNode(request.node).loots,
                ILootSystemV2(_gameRegistry.getSystem(LOOT_SYSTEM_V2_ID))
            );

            // Delete the VRF request
            delete _vrfRequests[requestId];
        }
    }

    /**
     * @inheritdoc IDungeonSystemV3
     */
    function getExtraTimeForDungeonCompletion() public view returns (uint256) {
        return
            Uint256Component(_gameRegistry.getComponent(UINT256_COMPONENT_ID))
                .getValue(DAILY_DUNGEONS_EXTRA_TIME_TO_COMPLETE);
    }

    /**
     * @inheritdoc IDungeonSystemV3
     */
    function getCurrentPlayerState(
        address account,
        uint256 dungeonScheduledStart
    ) external view returns (uint256, DungeonNodeProgressState) {
        return _getCurrentPlayerState(account, dungeonScheduledStart);
    }

    /**
     * @inheritdoc IDungeonSystemV3
     */
    function isDungeonMapCompleteForAccount(
        address account,
        uint256 dungeonScheduledStart
    ) external view returns (bool) {
        DungeonTrigger
            memory dungeonTrigger = _getDungeonTriggerByStartTimestamp(
                dungeonScheduledStart
            );
        (
            uint256 currentNode,
            DungeonNodeProgressState currentNodeState
        ) = _getCurrentPlayerState(account, dungeonScheduledStart);
        return
            currentNode ==
            _getDungeonMap(dungeonTrigger.dungeonMapEntity).nodes.length &&
            currentNodeState == DungeonNodeProgressState.VICTORY;
    }

    /** INTERNAL **/

    function _getTransformInputComponent()
        internal
        view
        returns (TransformInputComponent)
    {
        return
            TransformInputComponent(
                _gameRegistry.getComponent(TRANSFORM_INPUT_COMPONENT_ID)
            );
    }

    function _getTransferStatusComponent()
        internal
        view
        returns (TransferStatusComponent)
    {
        return
            TransferStatusComponent(
                _gameRegistry.getComponent(TRANSFER_STATUS_COMPONENT_ID)
            );
    }

    function _getCurrentPlayerState(
        address account,
        uint256 dungeonScheduledStart
    ) internal view returns (uint256, DungeonNodeProgressState) {
        IDungeonProgressSystem progressSystem = IDungeonProgressSystem(
            _getSystem(DUNGEON_PROGRESS_SYSTEM_ID)
        );

        uint256 currentNode = progressSystem.getCurrentNode(
            account,
            dungeonScheduledStart
        );
        DungeonNodeProgressState state = progressSystem.getStateForNode(
            account,
            dungeonScheduledStart,
            currentNode
        );

        return (currentNode, state);
    }

    function _getCurrentPlayerDungeonTriggerEntity(
        address account,
        uint256 mapEntity,
        uint256 dungeonScheduledStart
    ) internal pure returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(account, mapEntity, dungeonScheduledStart)
                )
            );
    }

    function _getDungeonTrigger(
        uint256 triggerIdx
    ) internal view returns (DungeonTrigger memory) {
        GauntletScheduleComponent scheduleComponent = GauntletScheduleComponent(
            _gameRegistry.getComponent(GauntletScheduleComponentId)
        );

        GauntletScheduleComponentLayout memory schedule = scheduleComponent
            .getLayoutValue(GAUNTLET_SCHEDULE_ENTITY);
        return
            DungeonTrigger({
                endAt: schedule.endTimestamps[triggerIdx],
                dungeonMapEntity: schedule.mapEntities[triggerIdx],
                startAt: schedule.startTimestamps[triggerIdx]
            });
    }

    function _getDungeonTriggerByStartTimestamp(
        uint256 scheduledStart
    ) internal view returns (DungeonTrigger memory result) {
        GauntletScheduleComponent scheduleComponent = GauntletScheduleComponent(
            _gameRegistry.getComponent(GauntletScheduleComponentId)
        );
        GauntletScheduleComponentLayout memory schedule = scheduleComponent
            .getLayoutValue(GAUNTLET_SCHEDULE_ENTITY);

        for (uint i = 0; i < schedule.mapEntities.length; i++) {
            if (schedule.startTimestamps[i] == scheduledStart) {
                result = DungeonTrigger({
                    endAt: schedule.endTimestamps[i],
                    dungeonMapEntity: schedule.mapEntities[i],
                    startAt: schedule.startTimestamps[i]
                });
                break;
            }
        }
    }

    function _getDungeonMap(
        uint256 dungeonMapEntity
    ) internal view returns (DungeonMap memory) {
        CombatMapComponent mapComponent = CombatMapComponent(
            _gameRegistry.getComponent(CombatMapComponentId)
        );
        CombatMapComponentLayout memory map = mapComponent.getLayoutValue(
            dungeonMapEntity
        );

        DungeonMap memory dungeonMap;
        dungeonMap.nodes = new DungeonNode[](map.encounterEntities.length);
        for (uint256 index = 0; index < map.encounterEntities.length; index++) {
            DungeonNode memory node = this.getDungeonNode(
                map.encounterEntities[index]
            );
            dungeonMap.nodes[index] = node;
        }

        return dungeonMap;
    }

    function _getDungeonNode(
        uint256 encounterEntity
    ) internal view returns (DungeonNode memory) {
        CombatEncounterComponent encounterComponent = CombatEncounterComponent(
            _gameRegistry.getComponent(CombatEncounterComponentId)
        );
        CombatEncounterComponentLayout memory encounter = encounterComponent
            .getLayoutValue(encounterEntity);

        return
            DungeonNode({
                nodeId: encounterEntity,
                enemies: encounter.enemyEntities,
                loots: LootArrayComponentLibrary.convertLootEntityArrayToLoot(
                    _gameRegistry.getComponent(LOOT_ENTITY_ARRAY_COMPONENT_ID),
                    encounter.lootEntity
                )
            });
    }

    function _generateTransferReceipt(
        address account,
        uint256 mapEntity,
        uint256 scheduledStart,
        TransformInputComponent transformInputComponent
    ) internal {
        // Check that the dungeon trigger is not already unlocked for player
        uint256 playerDungeonTriggerEntity = _getCurrentPlayerDungeonTriggerEntity(
                account,
                mapEntity,
                scheduledStart
            );

        // Check if a transfer has already been created
        TransferStatusComponent transferStatusComponent = _getTransferStatusComponent();
        if (
            transferStatusComponent
                .getLayoutValue(playerDungeonTriggerEntity)
                .status == uint8(TransferStatus.COMPLETED)
        ) {
            revert DungeonMapAlreadyUnlockedForPlayer(
                playerDungeonTriggerEntity
            );
        }

        // Generate unlock receipt
        TransferLibrary.generateTransferReceipt(
            address(transferStatusComponent),
            address(_gameRegistry.getComponent(CREATED_TIMESTAMP_COMPONENT_ID)),
            address(_gameRegistry.getComponent(LOOT_ENTITY_ARRAY_COMPONENT_ID)),
            address(0),
            account,
            playerDungeonTriggerEntity,
            LootArrayComponentLibrary.convertTransformInputToLootEntityArray(
                transformInputComponent.getLayoutValue(mapEntity)
            )
        );
    }

    /**
     * @dev Starts granting loot for a dungeon node, with or without VRF
     */
    function _grantLootBegin(LootRequest memory request) internal {
        ILootSystemV2 lootSystem = ILootSystemV2(
            _gameRegistry.getSystem(LOOT_SYSTEM_V2_ID)
        );
        ILootSystemV2.Loot[] memory loots = _getDungeonNode(request.node).loots;

        // Validate loots; returns true if VRF required.
        if (lootSystem.validateLoots(loots)) {
            // Generate a random number for the VRF request and
            // complete loot grant in fulfillRandomWordsCallback.
            uint256 requestId = _requestRandomWords(1);
            _vrfRequests[requestId] = request;
        } else {
            // Grant loot right away.
            _grantLootComplete(request, 0, loots, lootSystem);
        }
    }

    /**
     * @dev Finalizes loot granting for a dungeon node, after or without VRF
     */
    function _grantLootComplete(
        LootRequest memory request,
        uint256 randomWord,
        ILootSystemV2.Loot[] memory loots,
        ILootSystemV2 lootSystem
    ) internal {
        // Grant loot right away.
        lootSystem.grantLootWithRandomWord(request.account, loots, randomWord);

        // Emit granted event; used by client to find transfer logs.
        // NOTE: We're leaving this in for the Unity cutover, wil be removed in
        // the next iteration of the contracts.
        emit DungeonLootGranted({
            account: request.account,
            battleEntity: request.battleEntity,
            scheduledStartTimestamp: request.scheduledStartTimestamp,
            mapEntity: request.dungeonMapEntity,
            node: request.node
        });
    }

    function _validateDungeonMap(
        uint256 mapEntity,
        uint256 scheduledStart
    )
        internal
        view
        returns (DungeonMap memory map, DungeonTrigger memory trigger)
    {
        trigger = _getDungeonTriggerByStartTimestamp(scheduledStart);
        map = _getDungeonMap(trigger.dungeonMapEntity);

        // Check that mapEntity is valid
        if (trigger.dungeonMapEntity != mapEntity) {
            revert DungeonMapEntityMismatch(
                trigger.dungeonMapEntity,
                mapEntity
            );
        }

        // Check that the dungeon exists.
        if (map.nodes.length == 0) {
            revert DungeonMapNotFound(mapEntity, scheduledStart);
        }

        // Check that the dungeon has already started.
        if (trigger.startAt > block.timestamp) {
            revert DungeonNotAvailable(scheduledStart);
        }
    }

    // @note In this function, "currentNode" refers to the node that the user
    // was on prior to this call being made, and "nextNode" refers to the node
    // that the user is attempting to move to.
    function _validateStartDungeonBattle(
        address account,
        StartDungeonBattleParams memory params
    ) internal view {
        (
            DungeonMap memory map,
            DungeonTrigger memory trigger
        ) = _validateDungeonMap(params.mapEntity, params.scheduledStart);
        uint256 nextNode = params.encounterEntity;
        bool isStartingNewMap = nextNode == map.nodes[0].nodeId;

        // Check that the dungeon has not yet finished.
        // If they have already started the dungeon, they get a margin to finish.
        if (isStartingNewMap) {
            if (trigger.endAt < block.timestamp) {
                revert DungeonExpired(params.scheduledStart);
            }
        } else {
            if (
                (trigger.endAt + getExtraTimeForDungeonCompletion() <
                    block.timestamp)
            ) {
                revert DungeonExpired(params.scheduledStart);
            }
        }

        // Check that map entry fee is paid if required
        uint256 dungeonTriggerEntity = _getCurrentPlayerDungeonTriggerEntity(
            account,
            params.mapEntity,
            params.scheduledStart
        );
        if (
            isStartingNewMap &&
            _getTransformInputComponent().has(params.mapEntity) &&
            _getTransferStatusComponent()
                .getLayoutValue(dungeonTriggerEntity)
                .status !=
            uint8(TransferStatus.COMPLETED)
        ) {
            revert DungeonMapLockedForPlayer(dungeonTriggerEntity);
        }

        IDungeonProgressSystem progressSystem = IDungeonProgressSystem(
            _getSystem(DUNGEON_PROGRESS_SYSTEM_ID)
        );

        // Check previous node if they're not just starting the dungeon.
        DungeonNodeProgressState nextNodeState = progressSystem.getStateForNode(
            account,
            params.scheduledStart,
            nextNode
        );

        if (!isStartingNewMap) {
            uint256 currentNode = progressSystem.getCurrentNode(
                account,
                params.scheduledStart
            );

            // TODO: When we switch to the graph node based system, we'll need
            // to check the current node's next nodes to see if the node the
            // user requested was in the list.
            if (nextNodeState == DungeonNodeProgressState.UNVISITED) {
                // When starting a new node, check that the next node follows the current node.
                for (uint256 i = 0; i < map.nodes.length; i++) {
                    if (map.nodes[i].nodeId == currentNode) {
                        if (i + 1 < map.nodes.length) {
                            if (map.nodes[i + 1].nodeId != nextNode) {
                                revert DungeonNodeOutOfOrder(
                                    params.scheduledStart,
                                    nextNode
                                );
                            }
                        }
                    }
                }

                // When starting a new node, check that the previous node was victorious.
                if (
                    progressSystem.getStateForNode(
                        account,
                        params.scheduledStart,
                        currentNode
                    ) != DungeonNodeProgressState.VICTORY
                ) {
                    revert DungeonNodePreviousNotCompleted(
                        params.scheduledStart,
                        currentNode
                    );
                }
            }
        }

        // Check that the node hasn't already been completed.
        if (nextNodeState == DungeonNodeProgressState.VICTORY) {
            revert DungeonNodeAlreadyCompleted(params.scheduledStart, nextNode);
        }
    }

    function _markStartDungeonBattle(
        address account,
        StartDungeonBattleParams memory params,
        uint256 battleEntity
    ) internal {
        IDungeonProgressSystem progressSystem = IDungeonProgressSystem(
            _getSystem(DUNGEON_PROGRESS_SYSTEM_ID)
        );

        progressSystem.setCurrentNode(
            account,
            params.scheduledStart,
            params.encounterEntity
        );
        progressSystem.setStateForNode(
            account,
            params.scheduledStart,
            params.encounterEntity,
            DungeonNodeProgressState.STARTED
        );
        progressSystem.setBattleEntityForNode(
            account,
            params.scheduledStart,
            params.encounterEntity,
            battleEntity
        );
    }

    // @note In this function, "currentNode" is always the node being finished.
    function _validateEndDungeonBattle(
        address account,
        DungeonTrigger memory trigger,
        EndDungeonBattleParams memory params
    ) internal {
        DungeonMap memory map = _getDungeonMap(trigger.dungeonMapEntity);

        // Check that the dungeon exists.
        if (map.nodes.length == 0) {
            revert DungeonMapNotFound(
                trigger.dungeonMapEntity,
                params.scheduledStart
            );
        }

        // Check that the dungeon has already started, but not finished.
        if (
            trigger.startAt > block.timestamp || // Start is in the future
            (trigger.endAt + getExtraTimeForDungeonCompletion() <
                block.timestamp) // End is in the past, with extra time
        ) {
            revert DungeonExpired(params.scheduledStart);
        }

        IDungeonProgressSystem progressSystem = IDungeonProgressSystem(
            _getSystem(DUNGEON_PROGRESS_SYSTEM_ID)
        );

        // Check that this node has been started.
        uint256 currentNode = progressSystem.getCurrentNode(
            account,
            params.scheduledStart
        );
        if (currentNode != params.encounterEntity) {
            revert DungeonNodeOutOfOrder(
                params.scheduledStart,
                params.encounterEntity
            );
        }

        // Check that the node hasn't already been completed.
        if (
            progressSystem.getStateForNode(
                account,
                params.scheduledStart,
                params.encounterEntity
            ) != DungeonNodeProgressState.STARTED
        ) {
            revert DungeonNodeNotStarted(
                params.scheduledStart,
                params.encounterEntity
            );
        }

        // Check that the node's battleEntity matches.
        if (
            progressSystem.getBattleEntityForNode(
                account,
                params.scheduledStart,
                params.encounterEntity
            ) != params.battleEntity
        ) {
            revert DungeonNodeBattleEntityMismatch(
                params.scheduledStart,
                params.encounterEntity,
                params.battleEntity
            );
        }
    }

    function _markEndDungeonBattle(
        address account,
        EndDungeonBattleParams memory params
    ) internal {
        IDungeonProgressSystem progressSystem = IDungeonProgressSystem(
            _getSystem(DUNGEON_PROGRESS_SYSTEM_ID)
        );

        // Identify the winner of the battle and set the state accordingly.
        // NOTE: rely on DungeonBattleSystem to perform validations for victory.
        if (params.success) {
            progressSystem.setStateForNode(
                account,
                params.scheduledStart,
                params.encounterEntity,
                DungeonNodeProgressState.VICTORY
            );
        } else {
            progressSystem.setStateForNode(
                account,
                params.scheduledStart,
                params.encounterEntity,
                DungeonNodeProgressState.DEFEAT
            );
        }
    }

    /**
     * @notice Handles granting of AccountXp for a dungeon success or failure
     * @param account The account to grant AccountXp to
     * @param dungeonScheduledStart The dungeon trigger entity
     * @param success Whether the dungeon was successful or not
     */
    function _handleAccountXpGranting(
        address account,
        uint256 dungeonScheduledStart,
        bool success
    ) internal {
        // Get amount of AccountXp to grant
        AccountXpGrantedComponent accountXpGrantedComponent = AccountXpGrantedComponent(
                _gameRegistry.getComponent(ACCOUNT_XP_GRANTED_COMPONENT_ID)
            );
        // Use DungeonSystemV2 ID as the entity
        AccountXpGrantedComponentStruct
            memory accountXpGranted = accountXpGrantedComponent.getLayoutValue(
                ID
            );
        uint256 amountToGrant;
        if (success) {
            amountToGrant = accountXpGranted.successAmount;
        } else {
            amountToGrant = accountXpGranted.failAmount;
        }
        // Get current accrued AccountXp for this dungeon
        CountingSystem countingSystem = CountingSystem(
            _gameRegistry.getSystem(COUNTING_SYSTEM)
        );
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        uint256 currentAccruedXp = countingSystem.getCount(
            dungeonScheduledStart / 1 days,
            accountEntity
        );
        // Max daily amount reached or none available to grant
        if (
            amountToGrant == 0 ||
            currentAccruedXp >= accountXpGranted.maxAmountAllowed
        ) {
            return;
        }
        if (
            currentAccruedXp + amountToGrant >=
            accountXpGranted.maxAmountAllowed
        ) {
            amountToGrant =
                accountXpGranted.maxAmountAllowed -
                currentAccruedXp;
        }
        // Update CountingSystem
        countingSystem.incrementCount(
            dungeonScheduledStart / 1 days,
            accountEntity,
            amountToGrant
        );
        // Grant AccountXp
        IAccountXpSystem(_getSystem(ACCOUNT_XP_SYSTEM_ID)).grantAccountXp(
            accountEntity,
            amountToGrant
        );
    }

    function _startDungeonBattle(
        address account,
        StartDungeonBattleParams memory params
    ) internal returns (uint256) {
        // Can not start battles if banned.
        if (
            BanComponent(_gameRegistry.getComponent(BAN_COMPONENT_ID)).getValue(
                EntityLibrary.addressToEntity(account)
            ) == true
        ) {
            revert Banned();
        }

        // Validate
        _validateStartDungeonBattle(account, params);
        DungeonNode memory node = _getDungeonNode(params.encounterEntity);
        // Start battle
        uint256 battleEntity = IDungeonBattleSystemV2(
            _getSystem(DUNGEON_BATTLE_SYSTEM_ID)
        ).startBattle(account, params, node);
        _markStartDungeonBattle(account, params, battleEntity);
        return battleEntity;
    }

    function _endDungeonBattle(
        address account,
        EndDungeonBattleParams memory params
    ) internal {
        DungeonTrigger memory trigger = _getDungeonTriggerByStartTimestamp(
            params.scheduledStart
        );

        // Validate
        _validateEndDungeonBattle(account, trigger, params);

        // End battle
        IDungeonBattleSystemV2(_getSystem(DUNGEON_BATTLE_SYSTEM_ID)).endBattle(
            EndBattleParams({
                account: account,
                battleEntity: params.battleEntity,
                success: params.success
            })
        );

        // Update dungeon progress state.
        _markEndDungeonBattle(account, params);

        // Handle account-xp granting
        _handleAccountXpGranting(
            account,
            params.scheduledStart,
            params.success
        );

        // Grant loot if the battle was successful.
        if (params.success) {
            _grantLootBegin(
                LootRequest({
                    account: account,
                    battleEntity: params.battleEntity,
                    scheduledStartTimestamp: params.scheduledStart,
                    dungeonMapEntity: trigger.dungeonMapEntity,
                    node: params.encounterEntity
                })
            );
        }
    }
}
