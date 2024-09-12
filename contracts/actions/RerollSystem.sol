// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {RANDOMIZER_ROLE} from "../Constants.sol";

import {EntityLibrary} from "../core/EntityLibrary.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {GEM_TOKEN_ID} from "../gems/GemUtilitySystem.sol";
import {RerollConfigComponent, ID as REROLL_CONFIG_COMPONENT_ID, Layout as RerollConfigComponentStruct} from "../generated/components/RerollConfigComponent.sol";
import {RerollPendingComponent, ID as REROLL_PENDING_COMPONENT_ID, Layout as RerollPendingComponentStruct} from "../generated/components/RerollPendingComponent.sol";
import {GenerationComponent, ID as GENERATION_COMPONENT_ID} from "../generated/components/GenerationComponent.sol";
import {LevelComponent, ID as LEVEL_COMPONENT_ID} from "../generated/components/LevelComponent.sol";
import {ExpertiseComponent, ID as EXPERTISE_COMPONENT_ID} from "../generated/components/ExpertiseComponent.sol";
import {AffinityComponent, ID as AFFINITY_COMPONENT_ID} from "../generated/components/AffinityComponent.sol";
import {IsPirateComponent, ID as IS_PIRATE_COMPONENT_ID} from "../generated/components/IsPirateComponent.sol";
import {GameItems, ID as GAME_ITEMS_ID} from "../tokens/gameitems/GameItems.sol";

// ID of this contract
uint256 constant ID = uint256(keccak256("game.piratenation.rerollsystem"));

uint256 constant EXPERTISE_ROLL_CONFIG = uint256(
    keccak256("game.piratenation.rerollsystem.expertiseroll")
);

uint256 constant ELEMENTAL_AFFINITY_ROLL_CONFIG = uint256(
    keccak256("game.piratenation.rerollsystem.elementalaffinityroll")
);

/**
 * @title RerollSystem
 */
contract RerollSystem is GameRegistryConsumerUpgradeable {
    /** ERRORS **/

    /// @notice Invalid roll
    error InvalidRoll();

    error InvalidPirate();

    error InvalidPirateGeneration();

    error RerollPending();

    error NotOwner();

    struct VRFRequest {
        uint256 pirateEntity;
        bool expertiseRoll;
        bool affinityRoll;
    }

    /// @notice Mapping to track VRF requests
    mapping(uint256 => VRFRequest) private _vrfRequests;

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * @dev Roll affinity or Expertise for a pirate
     */
    function rerollPirateAffinityOrExpertise(
        uint256 pirateEntity,
        bool isExpertise,
        bool isAffinity
    ) external whenNotPaused nonReentrant {
        if (isExpertise == isAffinity) {
            revert InvalidRoll();
        }
        address caller = _getPlayerAccount(_msgSender());
        _checkValid(pirateEntity, caller);
        uint256 configEntityId = isExpertise
            ? EXPERTISE_ROLL_CONFIG
            : ELEMENTAL_AFFINITY_ROLL_CONFIG;
        _burnInputForPirate(caller, pirateEntity, configEntityId);
        // Kick off VRF
        uint256 requestId = _requestRandomWords(1);
        RerollPendingComponent rerollPendingComponent = RerollPendingComponent(
            _gameRegistry.getComponent(REROLL_PENDING_COMPONENT_ID)
        );

        RerollPendingComponentStruct
            memory rerollPending = rerollPendingComponent.getLayoutValue(
                pirateEntity
            );
        if (rerollPending.expertisePending && isExpertise) {
            revert RerollPending();
        }
        if (rerollPending.affinityPending && isAffinity) {
            revert RerollPending();
        }

        if (isExpertise) {
            rerollPending.expertisePending = true;
        } else {
            rerollPending.affinityPending = true;
        }

        rerollPendingComponent.setLayoutValue(pirateEntity, rerollPending);

        VRFRequest storage vrfRequest = _vrfRequests[requestId];
        vrfRequest.pirateEntity = pirateEntity;
        vrfRequest.expertiseRoll = isExpertise;
        vrfRequest.affinityRoll = isAffinity;
    }

    /**
     * @notice Callback function used by VRF Coordinator
     */
    function fulfillRandomWordsCallback(
        uint256 requestId,
        uint256[] memory randomWords
    ) external override onlyRole(RANDOMIZER_ROLE) {
        VRFRequest storage request = _vrfRequests[requestId];
        ExpertiseComponent expertiseComponent = ExpertiseComponent(
            _gameRegistry.getComponent(EXPERTISE_COMPONENT_ID)
        );
        AffinityComponent affinityComponent = AffinityComponent(
            _gameRegistry.getComponent(AFFINITY_COMPONENT_ID)
        );

        if (request.pirateEntity != 0) {
            uint256 randomWord = randomWords[0];
            uint256 currentVal = 0;
            if (request.expertiseRoll) {
                currentVal = expertiseComponent.getValue(request.pirateEntity);
            } else {
                currentVal = affinityComponent.getValue(request.pirateEntity);
            }

            uint256 newTrait = generateDifferentTrait(randomWord, currentVal);
            RerollPendingComponent rerollPendingComponent = RerollPendingComponent(
                    _gameRegistry.getComponent(REROLL_PENDING_COMPONENT_ID)
                );
            RerollPendingComponentStruct
                memory rerollPending = rerollPendingComponent.getLayoutValue(
                    request.pirateEntity
                );
            if (request.expertiseRoll) {
                rerollPending.expertisePending = false;
                expertiseComponent.setValue(request.pirateEntity, newTrait);
            } else {
                rerollPending.affinityPending = false;
                affinityComponent.setValue(
                    request.pirateEntity,
                    uint8(newTrait)
                );
            }
            rerollPendingComponent.setLayoutValue(
                request.pirateEntity,
                rerollPending
            );
            // Delete the VRF request
            delete _vrfRequests[requestId];
        }
    }

    /**
     * @notice Generates a new trait value different from the current one
     * @param randomWord The random word to use for generation
     * @param currentTrait The current trait value to avoid
     * @return A new trait value between 1 and 5, different from the current one
     */
    function generateDifferentTrait(
        uint256 randomWord,
        uint256 currentTrait
    ) private pure returns (uint256) {
        uint256 newTrait = (randomWord % 4) + 1; // Generate a number between 1 and 4
        if (newTrait >= currentTrait) {
            newTrait += 1; // Shift the value up by 1 if it's greater than or equal to the current trait
        }
        return newTrait;
    }

    function _checkValid(uint256 pirateEntity, address caller) internal view {
        (address tokenContract, uint256 tokenId) = EntityLibrary.entityToToken(
            pirateEntity
        );
        if (
            IsPirateComponent(
                _gameRegistry.getComponent(IS_PIRATE_COMPONENT_ID)
            ).getValue(pirateEntity) == false
        ) {
            revert InvalidPirate();
        }

        if (
            GenerationComponent(
                _gameRegistry.getComponent(GENERATION_COMPONENT_ID)
            ).getValue(pirateEntity) == 0
        ) {
            revert InvalidPirateGeneration();
        }

        // Check ownership
        if (IERC721(tokenContract).ownerOf(tokenId) != caller) {
            revert NotOwner();
        }
    }

    /** INTERNAL */

    /**
     * @dev Handles logic for burning a loot
     * */
    function _burnInputForPirate(
        address account,
        uint256 pirateEntity,
        uint256 configEntityId
    ) internal {
        uint256 pirateLevel = LevelComponent(
            _gameRegistry.getComponent(LEVEL_COMPONENT_ID)
        ).getValue(pirateEntity);

        RerollConfigComponentStruct memory config = RerollConfigComponent(
            _gameRegistry.getComponent(REROLL_CONFIG_COMPONENT_ID)
        ).getLayoutValue(configEntityId);

        uint256 totalGemCost = config.baseGemCost;
        if (pirateLevel > config.levelToScale) {
            totalGemCost +=
                (pirateLevel - config.levelToScale) *
                config.addedGemCostPerLevel;
        }

        GameItems(_gameRegistry.getSystem(GAME_ITEMS_ID)).burn(
            account,
            GEM_TOKEN_ID,
            totalGemCost
        );
    }
}
