// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/Strings.sol";

import {EntityLibrary} from "../core/EntityLibrary.sol";
import {LootArrayComponentLibrary} from "../loot/LootArrayComponentLibrary.sol";
import {TimeRangeLibrary} from "../core/TimeRangeLibrary.sol";
import {Glicko2Library, PlayerRatingData, INITIAL_RATING, INITIAL_DEVIATION, INITIAL_VOLATILITY, VICTORY, DEFEAT, RatingUpdateResult, PlayerRatingData} from "../core/Glicko2Library.sol";

import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {IGameItems} from "../tokens/gameitems/IGameItems.sol";
import {ILootSystemV2, ID as LOOT_SYSTEM_V2_ID} from "../loot/ILootSystemV2.sol";

import {UserPvpDataComponent, Layout as UserPvpDataComponentLayout, ID as USER_PVP_DATA_COMPONENT_ID} from "../generated/components/UserPvpDataComponent.sol";
import {LootEntityArrayComponent, Layout as LootEntityArrayLayout, ID as LOOT_ENTITY_ARRAY_COMPONENT_ID} from "../generated/components/LootEntityArrayComponent.sol";
import {EntityBaseComponent, ID as ENTITY_BASE_COMPONENT_ID} from "../generated/components/EntityBaseComponent.sol";
import {StaticEntityListComponent, ID as STATIC_ENTITY_LIST_COMPONENT_ID} from "../generated/components/StaticEntityListComponent.sol";
import {LootClaimedComponent, Layout as LootClaimedComponentLayout, ID as LOOT_CLAIMED_COMPONENT_ID} from "../generated/components/LootClaimedComponent.sol";
import {PvpLeagueDataComponent, Layout as PvpLeagueDataComponentLayout, ID as PVP_LEAGUE_DATA_COMPONENT_ID} from "../generated/components/PvpLeagueDataComponent.sol";
import {Uint256ArrayComponent, Layout as Uint256ArrayComponentLayout, ID as UINT256_ARRAY_COMPONENT_ID} from "../generated/components/Uint256ArrayComponent.sol";
import {TimeRangeComponent, ID as TIME_RANGE_COMPONENT_ID} from "../generated/components/TimeRangeComponent.sol";
import {PvpSummaryComponent, Layout as PvpSummaryComponentLayout, ID as PVP_SUMMARY_COMPONENT_ID} from "../generated/components/PvpSummaryComponent.sol";
import {TagsComponent, ID as TAGS_COMPONENT_ID} from "../generated/components/TagsComponent.sol";

// System ID for the PvP system
uint256 constant ID = uint256(keccak256("game.piratenation.pvpsystem"));

bytes32 constant PVP_VALIDATOR_ROLE = keccak256("PVP_VALIDATOR_ROLE");

// Global : League Trophy Thresholds
uint256 constant PVP_LEAGUE_TROPHY_THRESHOLDS = uint256(
    keccak256("game.piratenation.global.pvp_league_trophy_thresholds")
);

/** STRUCTS **/

/// @notice The result of a match
struct MatchDataResult {
    int256 ratingScore;
    int256 ratingDeviation;
    int256 ratingVolatility;
    uint32 lastUpdateTimestamp;
    uint8 outcome;
    uint256 gameSessionId;
    address opponentAddress;
    string ipfsUrl;
}

/// @notice Input for trophy adjustment
struct TrophyAdjustmentInput {
    address playerAddress;
    int256 ratingDifference;
    uint256 seasonId;
    uint8 outcome;
}

/// @notice The result of a trophy adjustment
struct TrophyAdjustmentResult {
    uint256 oldLeague;
    uint256 newLeague;
    uint256 trophyChange;
}

/** ERRORS **/

/// @notice Error when no PvP season is set
error NoPvpSeasonIdSet();

/// @notice Error when no trophy game item is set for a season
error NoTrophyGameItemSet();

/// @notice Error when the address is not a valid player
error InvalidPlayerAddress();

/// @notice Error when the rating inputs are invalid
error InvalidRatingInputs();

/// @notice Error when the game session ID is invalid
error InvalidGameSessionId();

/// @notice Error double report of a match
error DoubleReport(address playerOneAddress, uint256 gameSessionId);

/// @notice Error when the last played timestamp is invalid
error InvalidLastPlayedTimestamp();

/// @notice Error when invalid scaled inputs are used
error InvalidScaledInputs();

/// @notice Negative inputs are used
error NegativeInputs();

/** EVENTS **/

/// @notice Event when a match ends - no need to index opponent address as they will get their own event when they end their match
event EndMatch(uint256 indexed gameSessionId, address indexed playerAddress, uint8 indexed outcome, address opponentAddress, string ipfsUrl);

/**
 * @title PvP System
 * @notice Implements the PvP system
 */
contract PvpSystem is GameRegistryConsumerUpgradeable {
    /** SETUP **/

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /** EXTERNAL **/

    /**
     * Post the match results to the PvP system
     *
     * @param playerOneAddress The address of the player
     * @param matchDataResult The result of the match and the opponent's data
     */
    function postMatchResults(
        address playerOneAddress,
        MatchDataResult memory matchDataResult
    ) external onlyRole(PVP_VALIDATOR_ROLE) {
        // Validate inputs
        _validateInputs(playerOneAddress, matchDataResult);
        UserPvpDataComponent userPvpDataComponent = UserPvpDataComponent(
            _gameRegistry.getComponent(USER_PVP_DATA_COMPONENT_ID)
        );
        // Current PvP season running
        uint256 pvpSeasonId = EntityBaseComponent(
            _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
        ).getValue(ID);
        if (pvpSeasonId == 0) {
            revert NoPvpSeasonIdSet();
        }
        // If the PvP season is not active, return, no rewards or penalties or rating updates
        if (
            TimeRangeLibrary.checkWithinTimeRange(
                _gameRegistry.getComponent(TIME_RANGE_COMPONENT_ID),
                pvpSeasonId
            ) == false
        ) {
            return;
        }
        uint256 playerSeasonAddressEntity = EntityLibrary.accountSubEntity(
            playerOneAddress,
            pvpSeasonId
        );
        UserPvpDataComponentLayout memory playerPvpData = _initializePlayer(
            userPvpDataComponent,
            playerSeasonAddressEntity
        );
        int256 oldRating = playerPvpData.matchmakingRating;

        // Send to Glicko2Library to calculate new ratings
        RatingUpdateResult memory playerOneResult = Glicko2Library
            .calculateResultsUsingStats(
                PlayerRatingData({
                    ratingScore: playerPvpData.matchmakingRating,
                    ratingDeviation: playerPvpData.matchmakingRatingDeviation,
                    ratingVolatility: playerPvpData.matchmakingRatingVolatility,
                    lastUpdateTimestamp: playerPvpData
                        .matchmakingRatingLastUpdate
                }),
                PlayerRatingData({
                    ratingScore: matchDataResult.ratingScore,
                    ratingDeviation: matchDataResult.ratingDeviation,
                    ratingVolatility: matchDataResult.ratingVolatility,
                    lastUpdateTimestamp: matchDataResult.lastUpdateTimestamp
                }),
                matchDataResult.outcome
            );
        // Update player one's data with the new rating, deviation, and volatility
        playerPvpData.matchmakingRating = playerOneResult.newRating;
        playerPvpData.matchmakingRatingDeviation = playerOneResult.newDeviation;
        playerPvpData.matchmakingRatingVolatility = playerOneResult
            .newVolatility;
        playerPvpData.matchmakingRatingLastUpdate = uint32(block.timestamp);
        if (matchDataResult.outcome == VICTORY) {
            playerPvpData.winCount++;
        } else {
            playerPvpData.lossCount++;
        }
        // Update player one's data in the component
        UserPvpDataComponent(
            _gameRegistry.getComponent(USER_PVP_DATA_COMPONENT_ID)
        ).setLayoutValue(playerSeasonAddressEntity, playerPvpData);
        // Now handle the trophy adjustment
        TrophyAdjustmentResult memory trophyAdjustmentResult = _handleTrophyAdjustment(
                TrophyAdjustmentInput({
                    playerAddress: playerOneAddress,
                    ratingDifference: (playerPvpData.matchmakingRating -
                        oldRating) / 1000,
                    seasonId: pvpSeasonId,
                    outcome: matchDataResult.outcome
                })
            );
        uint256[] memory lootGrantedToRecord;
        // Handle winner ranking up if they won and moved up a league
        if (matchDataResult.outcome == VICTORY && trophyAdjustmentResult.newLeague > trophyAdjustmentResult.oldLeague) {
            lootGrantedToRecord = _handleRankedClaim(
                playerOneAddress,
                playerSeasonAddressEntity,
                trophyAdjustmentResult.newLeague,
                trophyAdjustmentResult.oldLeague
            );
        }
        // Store the battle summary
        _storeBattleSummaryWithTag(
            matchDataResult,
            pvpSeasonId,
            playerOneAddress,
            trophyAdjustmentResult.trophyChange,
            lootGrantedToRecord
        );
        // Emit the end match event
        _emitEndMatch(matchDataResult.gameSessionId, playerOneAddress, matchDataResult.outcome, matchDataResult.opponentAddress, matchDataResult.ipfsUrl);
    }

    /**
     * Post the match results to the PvP system for Lobby matches. This does not grant any trophies or rating updates.
     * @param playerOneAddress The address of the player
     * @param matchDataResult The result of the match
     */
    function postLobbyMatchResult(address playerOneAddress, MatchDataResult memory matchDataResult) external onlyRole(PVP_VALIDATOR_ROLE) {
        // Emit the end match event
        _emitEndMatch(matchDataResult.gameSessionId, playerOneAddress, matchDataResult.outcome, matchDataResult.opponentAddress, matchDataResult.ipfsUrl);
    }

    /** VIEW FUNCTIONS **/

    /**
     * Get the rating data for a player
     * @param playerAddress The address of the player
     * @return rating The rating of the player
     * @return deviation The deviation of the player
     * @return volatility The volatility of the player
     */
    function getRatingDataForPlayer(
        address playerAddress
    ) public view returns (int256, int256, int256, uint32, uint64, uint64) {
        uint256 pvpSeasonId = EntityBaseComponent(
            _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
        ).getValue(ID);
        uint256 playerSeasonAddressEntity = EntityLibrary.accountSubEntity(
            playerAddress,
            pvpSeasonId
        );
        UserPvpDataComponentLayout memory playerPvpData = UserPvpDataComponent(
            _gameRegistry.getComponent(USER_PVP_DATA_COMPONENT_ID)
        ).getLayoutValue(playerSeasonAddressEntity);
        if (playerPvpData.matchmakingRatingLastUpdate == 0) {
            return (
                INITIAL_RATING,
                INITIAL_DEVIATION,
                INITIAL_VOLATILITY,
                uint32(block.timestamp),
                0,
                0
            );
        }
        return (
            playerPvpData.matchmakingRating,
            playerPvpData.matchmakingRatingDeviation,
            playerPvpData.matchmakingRatingVolatility,
            playerPvpData.matchmakingRatingLastUpdate,
            playerPvpData.winCount,
            playerPvpData.lossCount
        );
    }

    /**
     * Get the league of a user based on their trophy count
     * @param playerAddress The address of the player
     * @param seasonId The ID of the season
     * @return userLeague The league of the user
     */
    function getUserLeague(
        address playerAddress,
        uint256 seasonId
    ) public view returns (uint256) {
        (address gameItemsAddress, uint256 seasonTrophyId) = EntityLibrary
            .entityToToken(
                EntityBaseComponent(
                    _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
                ).getValue(seasonId)
            );
        if (seasonTrophyId == 0) {
            revert NoTrophyGameItemSet();
        }
        // Get the trophy count for the user
        uint256 userTrophyCount = IGameItems(gameItemsAddress).balanceOf(
            playerAddress,
            seasonTrophyId
        );
        return _getUserLeague(userTrophyCount);
    }

    /**
     * @dev View function to get the match results for a player match against an opponent
     * Helper function to simulate the match results before they are posted
     */
    function getMatchResults(address playerOneAddress,
        MatchDataResult memory matchDataResult) external view returns (RatingUpdateResult memory playerOneResult, UserPvpDataComponentLayout memory oldData) {
        // Validate inputs
        _validateInputs(playerOneAddress, matchDataResult);
        UserPvpDataComponent userPvpDataComponent = UserPvpDataComponent(
            _gameRegistry.getComponent(USER_PVP_DATA_COMPONENT_ID)
        );
        // Current PvP season running
        uint256 pvpSeasonId = EntityBaseComponent(
            _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
        ).getValue(ID);
        
        uint256 playerSeasonAddressEntity = EntityLibrary.accountSubEntity(
            playerOneAddress,
            pvpSeasonId
        );
        oldData = _initializePlayer(
            userPvpDataComponent,
            playerSeasonAddressEntity
        );

        // Send to Glicko2Library to calculate new ratings
        playerOneResult = Glicko2Library
            .calculateResultsUsingStats(
                PlayerRatingData({
                    ratingScore: oldData.matchmakingRating,
                    ratingDeviation: oldData.matchmakingRatingDeviation,
                    ratingVolatility: oldData.matchmakingRatingVolatility,
                    lastUpdateTimestamp: oldData
                        .matchmakingRatingLastUpdate
                }),
                PlayerRatingData({
                    ratingScore: matchDataResult.ratingScore,
                    ratingDeviation: matchDataResult.ratingDeviation,
                    ratingVolatility: matchDataResult.ratingVolatility,
                    lastUpdateTimestamp: matchDataResult.lastUpdateTimestamp
                }),
                matchDataResult.outcome
            );
    }

    /** INTERNAL **/

    /**
     * Emit the end match event
     * @param gameSessionId The ID of the game session
     * @param playerAddress The address of the player
     * @param outcome The outcome of the match
     * @param opponentAddress The address of the opponent
     * @param ipfsUrl The IPFS URL of the match
     */
    function _emitEndMatch(uint256 gameSessionId, address playerAddress, uint8 outcome, address opponentAddress, string memory ipfsUrl) internal {
        emit EndMatch(gameSessionId, playerAddress, outcome, opponentAddress, ipfsUrl);
    }

    /**
     * Initialize a player's PvP data if it doesn't exist or returns the existing data
     *
     * @param userPvpDataComponent The UserPvpDataComponent instance
     * @param playerSeasonAddressEntity The entity ID of the player
     * @return userPvpDataComponentLayout The player's PvP data initialized
     */
    function _initializePlayer(
        UserPvpDataComponent userPvpDataComponent,
        uint256 playerSeasonAddressEntity
    ) internal view returns (UserPvpDataComponentLayout memory) {
        UserPvpDataComponentLayout memory userPvpData = userPvpDataComponent
            .getLayoutValue(playerSeasonAddressEntity);
        if (userPvpData.matchmakingRatingLastUpdate == 0) {
            userPvpData.matchmakingRating = INITIAL_RATING;
            userPvpData.matchmakingRatingDeviation = INITIAL_DEVIATION;
            userPvpData.matchmakingRatingVolatility = INITIAL_VOLATILITY;
            userPvpData.matchmakingRatingLastUpdate = uint32(block.timestamp);
        }
        return userPvpData;
    }

    /**
     * Handle the trophy adjustment for a win or loss, return old league and new league
     *
     * @param trophyAdjustmentInput Contains the inputs for the trophy adjustment
     */
    function _handleTrophyAdjustment(
        TrophyAdjustmentInput memory trophyAdjustmentInput
    ) internal returns (TrophyAdjustmentResult memory) {
        // If rating difference is so miniscule that it's 0, set to 1 for trophy adjustment
        if(trophyAdjustmentInput.ratingDifference == 0) {
            trophyAdjustmentInput.ratingDifference = 1;
        }
        (address gameItemsAddress, uint256 seasonTrophyId) = EntityLibrary
            .entityToToken(
                EntityBaseComponent(
                    _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
                ).getValue(trophyAdjustmentInput.seasonId)
            );
        if (seasonTrophyId == 0) {
            revert NoTrophyGameItemSet();
        }
        // Get the trophy count for the user
        uint256 currentTrophyCount = IGameItems(gameItemsAddress).balanceOf(
            trophyAdjustmentInput.playerAddress,
            seasonTrophyId
        );

        uint256 userCurrentLeague = _getUserLeague(currentTrophyCount);
        // Get any league data defined for the league
        PvpLeagueDataComponentLayout memory leagueData = PvpLeagueDataComponent(
            _gameRegistry.getComponent(PVP_LEAGUE_DATA_COMPONENT_ID)
        ).getLayoutValue(
                StaticEntityListComponent(
                    _gameRegistry.getComponent(STATIC_ENTITY_LIST_COMPONENT_ID)
                ).getValue(ID)[userCurrentLeague]
            );
        uint256 trophyAmountToGrantOrBurn = uint256(
            Glicko2Library.abs(trophyAdjustmentInput.ratingDifference)
        );
        if (trophyAdjustmentInput.outcome == VICTORY) {
            // Enforce ceiling for win
            if (
                leagueData.winConstant != 0 &&
                trophyAmountToGrantOrBurn > leagueData.winConstant
            ) {
                trophyAmountToGrantOrBurn = leagueData.winConstant;
                trophyAdjustmentInput.ratingDifference = int256(
                    leagueData.winConstant
                );
            }
            // Use rating difference to determine how many trophies to award
            if(trophyAmountToGrantOrBurn > 0) {
                IGameItems(gameItemsAddress).mint(
                    trophyAdjustmentInput.playerAddress,
                    seasonTrophyId,
                    trophyAmountToGrantOrBurn
                );
            }
        } else if (
            trophyAdjustmentInput.outcome == DEFEAT && currentTrophyCount == 0
        ) {
            trophyAmountToGrantOrBurn = 0;
            trophyAdjustmentInput.ratingDifference = 0;
        } else if (
            trophyAdjustmentInput.outcome == DEFEAT && currentTrophyCount > 0
        ) {
            // Use rating difference to determine how many trophies to burn, if user in certain league then burn certain amount
            // Enforce ceiling for loss
            if (
                leagueData.lossConstant != 0 &&
                trophyAmountToGrantOrBurn > leagueData.lossConstant
            ) {
                trophyAdjustmentInput.ratingDifference = int256(
                    leagueData.lossConstant
                );
                trophyAmountToGrantOrBurn = leagueData.lossConstant;
            }
            if (currentTrophyCount <= trophyAmountToGrantOrBurn) {
                trophyAdjustmentInput.ratingDifference = int256(
                    currentTrophyCount
                );
                trophyAmountToGrantOrBurn = currentTrophyCount;
            }
            IGameItems(gameItemsAddress).burn(
                trophyAdjustmentInput.playerAddress,
                seasonTrophyId,
                trophyAmountToGrantOrBurn
            );
        }
        // Return the old league and new league and trophy change
        return TrophyAdjustmentResult({
            oldLeague: userCurrentLeague,
            newLeague: _getUserLeague(
                IGameItems(gameItemsAddress).balanceOf(
                    trophyAdjustmentInput.playerAddress,
                    seasonTrophyId
                )
            ),
            trophyChange: trophyAmountToGrantOrBurn
        });
    }

    /**
     * Handle the ranking up of a user
     * @param winnerAddress The address of the winner
     * @param playerSeasonAddressEntity The entity ID of the player
     * @param newLeague The new league of the player
     * @param oldLeague The old league of the player
     */
    function _handleRankedClaim(
        address winnerAddress,
        uint256 playerSeasonAddressEntity,
        uint256 newLeague,
        uint256 oldLeague
    ) internal returns (uint256[] memory) {
        uint256[] memory leagues = StaticEntityListComponent(
            _gameRegistry.getComponent(STATIC_ENTITY_LIST_COMPONENT_ID)
        ).getValue(ID);
        uint256[] memory lootGrantedToRecord = new uint256[](leagues.length);
        // Get current user loot claimed
        uint256[] memory userLootClaimed = LootClaimedComponent(
            _gameRegistry.getComponent(LOOT_CLAIMED_COMPONENT_ID)
        ).getValue(playerSeasonAddressEntity);
        uint256 newLeagueEntity;
        uint256 lootGrantedIndex = 0;
        for (uint256 i = oldLeague; i <= newLeague; i++) {
            newLeagueEntity = leagues[i];
            bool hasClaimed = false;
            for (uint256 j = 0; j < userLootClaimed.length; j++) {
                if (userLootClaimed[j] == newLeagueEntity) {
                    hasClaimed = true;
                    break;
                }
            }
            if (hasClaimed == false) {
                // Grant the loot for this rank
                ILootSystemV2.Loot[]
                    memory leagueLoot = LootArrayComponentLibrary
                        .convertLootEntityArrayToLoot(
                            _gameRegistry.getComponent(
                                LOOT_ENTITY_ARRAY_COMPONENT_ID
                            ),
                            newLeagueEntity
                        );
                if (leagueLoot.length > 0) {
                    ILootSystemV2(_getSystem(LOOT_SYSTEM_V2_ID)).grantLoot(
                        winnerAddress,
                        leagueLoot
                    );
                    lootGrantedToRecord[lootGrantedIndex] = newLeagueEntity;
                    lootGrantedIndex++;
                }
            }
        }
        // Resize the lootGrantedToRecord array
        uint256 reduceArrayLengthBy = leagues.length - lootGrantedIndex;
        assembly {
            mstore(
                lootGrantedToRecord,
                sub(mload(lootGrantedToRecord), reduceArrayLengthBy)
            )
        }

        if (lootGrantedIndex > 0) {
            LootClaimedComponent(
                _gameRegistry.getComponent(LOOT_CLAIMED_COMPONENT_ID)
            ).append(
                    playerSeasonAddressEntity,
                    LootClaimedComponentLayout(lootGrantedToRecord)
                );
        }
        return lootGrantedToRecord;
    }

    /**
     * Get the league of a user based on their trophy count
     * @param trophyCount The number of trophies the user has
     * @return userLeague The league of the user
     */
    function _getUserLeague(
        uint256 trophyCount
    ) internal view returns (uint256) {
        // Get league thresholds
        uint256[] memory leagueThresholds = Uint256ArrayComponent(
            _gameRegistry.getComponent(UINT256_ARRAY_COMPONENT_ID)
        ).getValue(PVP_LEAGUE_TROPHY_THRESHOLDS);
        uint256 userLeague = 0;
        if (trophyCount >= leagueThresholds[leagueThresholds.length - 1]) {
            userLeague = leagueThresholds.length - 1;
        } else {
            for (uint256 i = 0; i < leagueThresholds.length; i++) {
                if (trophyCount < leagueThresholds[i + 1]) {
                    userLeague = i;
                    break;
                }
            }
        }
        return userLeague;
    }

    /**
     * Store the battle summary with a tag
     * @param matchDataResult The result of the match
     * @param pvpSeasonId The ID of the PvP season
     * @param playerAddress The address of the player
     * @param trophyChange The change in trophies
     * @param lootGrantedToRecord The loot granted to the player
     */
    function _storeBattleSummaryWithTag(
        MatchDataResult memory matchDataResult,
        uint256 pvpSeasonId,
        address playerAddress,
        uint256 trophyChange,
        uint256[] memory lootGrantedToRecord
    ) internal {
        PvpSummaryComponent pvpSummaryComponent = PvpSummaryComponent(
            _gameRegistry.getComponent(PVP_SUMMARY_COMPONENT_ID)
        );
        uint256 playeGameSessionEntity = EntityLibrary.accountSubEntity(
            playerAddress,
            matchDataResult.gameSessionId
        );
        if (pvpSummaryComponent.has(playeGameSessionEntity)) {
            revert DoubleReport(playerAddress, matchDataResult.gameSessionId);
        }
        pvpSummaryComponent.setLayoutValue(
            playeGameSessionEntity,
            PvpSummaryComponentLayout({
                lootGrantedToRecord: lootGrantedToRecord,
                trophyChange: int256(trophyChange),
                battleOutcome: matchDataResult.outcome,
                battleTimestamp: uint32(block.timestamp),
                opponentAddress: matchDataResult.opponentAddress,
                ipfsUrl: matchDataResult.ipfsUrl
            })
        );
        // Store the battle summary
        string memory battleSummaryTag = string.concat(
            Strings.toHexString(playerAddress),
            " + ",
            Strings.toString(pvpSeasonId)
        );
        string[] memory tags = new string[](1);
        tags[0] = battleSummaryTag;
        TagsComponent(_gameRegistry.getComponent(TAGS_COMPONENT_ID)).setValue(
            playeGameSessionEntity,
            tags
        );
    }

    /**
     * Validate the inputs of a match
     * @param playerOneAddress The address of the player
     * @param matchDataResult The result of the match
     */
    function _validateInputs(
        address playerOneAddress,
        MatchDataResult memory matchDataResult
    ) internal view {
        // Check wallet addresses
        if (
            playerOneAddress == matchDataResult.opponentAddress ||
            playerOneAddress == address(0) ||
            matchDataResult.opponentAddress == address(0)
        ) {
            revert InvalidPlayerAddress();
        }
        // Check game session ID
        if (matchDataResult.gameSessionId == 0) {
            revert InvalidGameSessionId();
        }
        // Check rating inputs
        if (
            matchDataResult.ratingScore == 0 ||
            matchDataResult.ratingDeviation == 0 ||
            matchDataResult.ratingVolatility == 0
        ) {
            revert InvalidRatingInputs();
        }
        // Check valid last played timestamp posted
        if(matchDataResult.lastUpdateTimestamp == 0 || matchDataResult.lastUpdateTimestamp > block.timestamp) {
            revert InvalidLastPlayedTimestamp();
        }
        // Check valid scaled inputs
        if(matchDataResult.ratingScore / 1000 == 0 || matchDataResult.ratingDeviation / 1000 == 0 || matchDataResult.ratingVolatility / 1000 == 0) {
            revert InvalidScaledInputs();
        }
        // Check negative inputs
        if(matchDataResult.ratingScore < 0 || matchDataResult.ratingDeviation < 0 || matchDataResult.ratingVolatility < 0) {
            revert NegativeInputs();
        }
    }
}
