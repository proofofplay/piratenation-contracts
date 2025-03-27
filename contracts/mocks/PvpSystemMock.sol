// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.26;

import "../combat/PvpSystem.sol";
import {UserPvpDataComponent} from "../generated/components/UserPvpDataComponent.sol";

/** @title PvpSystem Mock for testing */
contract PvpSystemMock is PvpSystem {
    struct PlayerGlobalData {
        uint256 currentLeague;
        uint256 currentRating;
        uint256 currentTrophyCount;
        uint256 lastUpdateTimestamp;
    }

    // Temporary mapping to record the match data result to mapping
    mapping(address => mapping(uint256 => MatchDataResult))
        public playerAddressToGameSessionIdToMatchDataResult;
    // Temporary mapping to store the player's global data
    mapping(address => PlayerGlobalData) public playerAddressToPlayerGlobalData;

    // function postMatchResults(
    //     address playerOneAddress,
    //     MatchDataResult memory matchDataResult
    // ) external override {
    //     super.postMatchResults(playerOneAddress, matchDataResult);
    // }

    function setTestRating(address playerAddress, int256 rating) public {
        UserPvpDataComponent userPvpDataComponent = UserPvpDataComponent(
            _gameRegistry.getComponent(USER_PVP_DATA_COMPONENT_ID)
        );
        uint256 pvpSeasonId = EntityBaseComponent(
            _gameRegistry.getComponent(ENTITY_BASE_COMPONENT_ID)
        ).getValue(ID);
        if (pvpSeasonId == 0) {
            revert NoPvpSeasonIdSet();
        }
        uint256 playerSeasonAddressEntity = EntityLibrary.accountSubEntity(
            playerAddress,
            pvpSeasonId
        );
        UserPvpDataComponentLayout memory playerPvpData = _initializePlayer(
            userPvpDataComponent,
            playerSeasonAddressEntity
        );
        playerPvpData.matchmakingRating = rating * 1000;
        userPvpDataComponent.setLayoutValue(
            playerSeasonAddressEntity,
            playerPvpData
        );
    }
}
