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
        (
            uint256 oldLeague,
            uint256 newLeague,
            int256 trophyChange
        ) = _handleTrophyAdjustment(
                playerOneAddress,
                (playerPvpData.matchmakingRating - oldRating) / 1000,
                pvpSeasonId,
                matchDataResult.outcome
            );
        uint256[] memory lootGrantedToRecord;
        // Handle winner ranking up if they won and moved up a league
        if (matchDataResult.outcome == VICTORY && newLeague > oldLeague) {
            lootGrantedToRecord = _handleRankedClaim(
                playerOneAddress,
                playerSeasonAddressEntity,
                newLeague,
                oldLeague
            );
        }
        // Store the battle summary
        _storeBattleSummaryWithTag(
            matchDataResult,
            pvpSeasonId,
            playerOneAddress,
            trophyChange,
            lootGrantedToRecord
        );
    }

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
        if (playerPvpData.matchmakingRating == 0) {
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

    /** INTERNAL **/

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
        if (userPvpData.matchmakingRating == 0) {
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
     * @param playerAddress The address of the player
     * @param ratingDifference The difference in rating whether rating increased or decreased
     * @param outcome The outcome of the match
     */
    function _handleTrophyAdjustment(
        address playerAddress,
        int256 ratingDifference,
        uint256 seasonId,
        uint8 outcome
    ) internal returns (uint256, uint256, int256) {
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
        uint256 currentTrophyCount = IGameItems(gameItemsAddress).balanceOf(
            playerAddress,
            seasonTrophyId
        );

        uint256 userCurrentLeague = _getUserLeague(currentTrophyCount);
        if (outcome == VICTORY) {
            // Use rating difference to determine how many trophies to award
            IGameItems(gameItemsAddress).mint(
                playerAddress,
                seasonTrophyId,
                uint256(Glicko2Library.abs(ratingDifference))
            );
        } else if (outcome == DEFEAT) {
            // Use rating difference to determine how many trophies to burn, if user in certain league then burn certain amount
            // Match the user league to the league entity
            // Get any league data defined for the league
            PvpLeagueDataComponentLayout
                memory leagueData = PvpLeagueDataComponent(
                    _gameRegistry.getComponent(PVP_LEAGUE_DATA_COMPONENT_ID)
                ).getLayoutValue(
                        StaticEntityListComponent(
                            _gameRegistry.getComponent(
                                STATIC_ENTITY_LIST_COMPONENT_ID
                            )
                        ).getValue(ID)[userCurrentLeague]
                    );
            // Burn a defined amount of trophies if needed
            if (leagueData.lossConstant != 0) {
                ratingDifference = int256(leagueData.lossConstant);
            }
            if (currentTrophyCount >= uint256(ratingDifference)) {
                ratingDifference = int256(currentTrophyCount);
            } else {
                ratingDifference = int256(currentTrophyCount);
            }
            IGameItems(gameItemsAddress).burn(
                playerAddress,
                seasonTrophyId,
                uint256(Glicko2Library.abs(ratingDifference))
            );
        }
        // Return the old league and new league
        return (
            userCurrentLeague,
            _getUserLeague(
                IGameItems(gameItemsAddress).balanceOf(
                    playerAddress,
                    seasonTrophyId
                )
            ),
            ratingDifference
        );
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
        if (trophyCount > leagueThresholds[leagueThresholds.length - 1]) {
            userLeague = leagueThresholds.length - 1;
        } else {
            for (uint256 i = 0; i < leagueThresholds.length; i++) {
                if (trophyCount < leagueThresholds[i]) {
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
        int256 trophyChange,
        uint256[] memory lootGrantedToRecord
    ) internal {
        PvpSummaryComponent pvpSummaryComponent = PvpSummaryComponent(
            _gameRegistry.getComponent(PVP_SUMMARY_COMPONENT_ID)
        );
        pvpSummaryComponent.setLayoutValue(
            EntityLibrary.accountSubEntity(
                playerAddress,
                matchDataResult.gameSessionId
            ),
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
            EntityLibrary.accountSubEntity(
                playerAddress,
                matchDataResult.gameSessionId
            ),
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
    ) internal pure {
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
    }
}
