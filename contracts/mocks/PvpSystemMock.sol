// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.26;

import "../combat/PvpSystem.sol";

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
}
