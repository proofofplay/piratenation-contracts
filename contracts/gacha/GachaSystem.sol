// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../GameRegistryConsumerUpgradeable.sol";
import {LootArrayComponentLibrary} from "../loot/LootArrayComponentLibrary.sol";
import {TimeRangeLibrary} from "../core/TimeRangeLibrary.sol";
import {ILootSystemV2, ID as LOOT_SYSTEM_V2_ID} from "../loot/ILootSystemV2.sol";

import {IGachaSystem, ID} from "./IGachaSystem.sol";
import {StarterPirateSystemV2, ID as STARTER_PIRATE_SYSTEM_ID} from "../starterpirate/StarterPirateSystemV2.sol";

import {GachaComponent, Layout as GachaComponentLayout, ID as GACHA_COMPONENT_ID} from "../generated/components/GachaComponent.sol";
import {ActiveGachasComponent, Layout as ActiveGachasComponentLayout, ID as ACTIVE_GACHAS_COMPONENT_ID} from "../generated/components/ActiveGachasComponent.sol";
import {CounterComponent, ID as COUNTER_COMPONENT_ID} from "../generated/components/CounterComponent.sol";
import {EnabledComponent, ID as ENABLED_COMPONENT_ID} from "../generated/components/EnabledComponent.sol";
import {LootEntityArrayComponent, Layout as LootEntityArrayComponentLayout, ID as LOOT_ENTITY_ARRAY_COMPONENT_ID} from "../generated/components/LootEntityArrayComponent.sol";
import {ID as TIME_RANGE_COMPONENT_ID} from "../generated/components/TimeRangeComponent.sol";

import {VRF_SYSTEM_ROLE} from "../Constants.sol";

/**
 * @title GachaSystem
 * @notice System used for wishing well feature
 */
contract GachaSystem is IGachaSystem, GameRegistryConsumerUpgradeable {
    /** STRUCTS */

    // VRFRequest: Struct to track and respond to VRF requests
    struct VRFRequest {
        address account;
        uint256 gachaComponentId;
    }

    /** MEMBERS */

    /// @notice Mapping to track VRF requests
    mapping(uint256 => VRFRequest) private _vrfRequests;

    /** ERRORS */

    /// @notice Error when invalid zero inputs used
    error InvalidInputs();

    /// @notice Error when a Gacha is not available
    error GachaNotAvailable();

    /// @notice Error when a Gacha is not setup
    error GachaNotSetup(uint256 gachaLootComponentId);

    /// @notice Error when a Gacha is empty
    error GachaEmpty(uint256 gachaLootComponentId);

    /** EVENTS */

    event GachaComplete(uint256 gachaLootComponentId, address account);

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /** SETTERS */

    /**
     * @dev Dispense a random item from a Gacha
     * @param gachaComponentId ID of the GachaLootComponent to interact with
     */
    function dispense(
        uint256 gachaComponentId
    ) external override nonReentrant whenNotPaused {
        // Check inputs
        if (gachaComponentId == 0) {
            revert InvalidInputs();
        }
        // Get user account
        address account = _getPlayerAccount(_msgSender());
        // Check active status
        _checkActiveStatus(gachaComponentId);

        GachaComponent gachaComponent = GachaComponent(
            _gameRegistry.getComponent(GACHA_COMPONENT_ID)
        );

        GachaComponentLayout memory gachaComponentLayout = gachaComponent
            .getLayoutValue(gachaComponentId);
        if (gachaComponentLayout.inputLootEntity == 0) {
            revert GachaNotSetup(gachaComponentId);
        }

        // Handle entry fee
        LootArrayComponentLibrary.burnV2Loot(
            LootArrayComponentLibrary.convertLootEntityArrayToLoot(
                address(_gameRegistry.getComponent(LOOT_ENTITY_ARRAY_COMPONENT_ID)),
                gachaComponentLayout.inputLootEntity
            ),
            account
        );

        // Empty Gacha check
        CounterComponent counterComponent = CounterComponent(
            _gameRegistry.getComponent(COUNTER_COMPONENT_ID)
        );
        uint256 currentCount = counterComponent.getValue(gachaComponentId);
        if (currentCount == 0) {
            revert GachaEmpty(gachaComponentId);
        }
        counterComponent.setValue(gachaComponentId, currentCount - 1);

        // Kick off VRF request
        VRFRequest storage vrfRequest = _vrfRequests[_requestRandomNumber(0)];
        vrfRequest.account = account;
        vrfRequest.gachaComponentId = gachaComponentId;
    }

    /**
     * @notice Callback function used by VRF Coordinator
     */
    function randomNumberCallback(
        uint256 requestId,
        uint256 randomNumber
    ) external override onlyRole(VRF_SYSTEM_ROLE) {
        VRFRequest storage request = _vrfRequests[requestId];
        if (request.account != address(0)) {
            GachaComponent gachaComponent = GachaComponent(
                _gameRegistry.getComponent(GACHA_COMPONENT_ID)
            );

            GachaComponentLayout memory gachaComponentLayout = gachaComponent
                .getLayoutValue(request.gachaComponentId);
            uint256 currLength = gachaComponentLayout.gachaLength;
            // Decrement total gacha supply by 1
            gachaComponentLayout.gachaLength--;
            gachaComponent.setLayoutValue(
                request.gachaComponentId,
                gachaComponentLayout
            );
            uint256 subLength = currLength - 1;

            uint256 randomIndex = randomNumber % currLength;

            LootEntityArrayComponent lootEntityArrayComponent = LootEntityArrayComponent(
                    _gameRegistry.getComponent(LOOT_ENTITY_ARRAY_COMPONENT_ID)
                );

            //pull the lootItem for that Index
            //todo: Should these be keccak's instead of this weird + 1 thing.
            LootEntityArrayComponentLayout
                memory randomLoot = lootEntityArrayComponent.getLayoutValue(
                    request.gachaComponentId + randomIndex
                );

            LootEntityArrayComponentLayout
                memory lastLoot = lootEntityArrayComponent.getLayoutValue(
                    request.gachaComponentId + subLength
                );

            // if item is not the last in the array, we should swap it with the last item in the array
            if (randomIndex != subLength) {
                //swap the lastLootEntity with the randomLootEntity
                lootEntityArrayComponent.setLayoutValue(
                    request.gachaComponentId + randomIndex,
                    lastLoot
                );
            }

            //remove the last element from the association so it can no longer be pulled.
            lootEntityArrayComponent.remove(
                request.gachaComponentId + subLength
            );

            _rewardLoots(randomLoot, request.account, randomNumber);

            emit GachaComplete(request.gachaComponentId, request.account);
            // Delete the VRF request
            delete _vrfRequests[requestId];
        }
    }

    /** GETTERS */

    /**
     * @dev Gets the current count of items in a Gacha
     * @param gachaLootComponentId ID of the GachaLootComponent
     */
    function supply(
        uint256 gachaLootComponentId
    ) external view override returns (uint256) {
        CounterComponent counterComponent = CounterComponent(
            _gameRegistry.getComponent(COUNTER_COMPONENT_ID)
        );
        uint256 remainingItems = counterComponent.getValue(
            gachaLootComponentId
        );
        return remainingItems;
    }

    /** INTERNAL **/

    /**
     * Rewards all loots inside the LootArray to the given account
     * Todo: This should be inside of loot system instead of here.
     */
    function _rewardLoots(
        LootEntityArrayComponentLayout memory randomLoot,
        address account,
        uint256 randomWord
    ) internal {
        ILootSystemV2.Loot[] memory loot = new ILootSystemV2.Loot[](
            randomLoot.lootType.length
        );

        for (uint i = 0; i < randomLoot.lootType.length; i++) {
            loot[i] = ILootSystemV2.Loot(
                ILootSystemV2.LootType(randomLoot.lootType[i]),
                randomLoot.lootEntity[i],
                randomLoot.amount[i]
            );
        }
        ILootSystemV2(_getSystem(LOOT_SYSTEM_V2_ID)).grantLootWithRandomWord(
            account,
            loot,
            randomWord
        );
    }

    function _checkActiveStatus(uint256 gachaComponentId) internal view {
        // Get active gachas tied to this system and check if active
        ActiveGachasComponentLayout memory activeGachas = ActiveGachasComponent(
            _gameRegistry.getComponent(ACTIVE_GACHAS_COMPONENT_ID)
        ).getLayoutValue(ID);
        bool activeGacha;
        for (uint256 i = 0; i < activeGachas.activeGachaEntities.length; i++) {
            if (activeGachas.activeGachaEntities[i] == gachaComponentId) {
                activeGacha = true;
                break;
            }
        }
        if (!activeGacha) {
            revert GachaNotAvailable();
        }
        bool enabledStatus = EnabledComponent(
            _gameRegistry.getComponent(ENABLED_COMPONENT_ID)
        ).getValue(gachaComponentId);
        if (!enabledStatus) {
            revert GachaNotAvailable();
        }
        bool isActive = TimeRangeLibrary.checkWithinOptionalTimeRange(
            _gameRegistry.getComponent(TIME_RANGE_COMPONENT_ID),
            gachaComponentId
        );
        if (!isActive) {
            revert GachaNotAvailable();
        }
    }
}
