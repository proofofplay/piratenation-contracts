// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {PERCENTAGE_RANGE} from "../Constants.sol";

library RandomLibrary {
    // Generates a new random word from a previous random word
    function generateNextRandomWord(
        uint256 randomWord
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(randomWord)));
    }

    /**
     * Perform a weighted coinflip to determine success or failure.
     * @param randomWord    VRF generated random word, will be incremented before used
     * @param successRate   Between 0 - PERCENTAGE_RANGE. Chance of success (0 = 0%, 10000 = 100%)
     * @return success      Whether flip was successful
     * @return nextRandomWord   Random word that was used to flip
     */
    function weightedCoinFlip(
        uint256 randomWord,
        uint256 successRate
    ) internal pure returns (bool success, uint256 nextRandomWord) {
        if (successRate >= PERCENTAGE_RANGE) {
            success = true;
            nextRandomWord = randomWord;
        } else {
            nextRandomWord = generateNextRandomWord(randomWord);
            success = nextRandomWord % PERCENTAGE_RANGE < successRate;
        }
    }

    /**
     * Perform a multiple weighted coinflips to determine success or failure.
     *
     * @param randomWord    VRF generated random word, will be incremented before used
     * @param successRate   Between 0 - PERCENTAGE_RANGE. Chance of success (0 = 0%, 10000 = 100%)
     * @param amount        Number of flips to perform
     * @return numSuccess   How many flips were successful
     * @return nextRandomWord   Last random word that was used to flip
     */
    function weightedCoinFlipBatch(
        uint256 randomWord,
        uint256 successRate,
        uint16 amount
    ) internal pure returns (uint16 numSuccess, uint256 nextRandomWord) {
        if (successRate >= PERCENTAGE_RANGE) {
            numSuccess = amount;
            nextRandomWord = randomWord;
        } else {
            numSuccess = 0;
            for (uint256 idx; idx < amount; ++idx) {
                nextRandomWord = generateNextRandomWord(randomWord);
                if (nextRandomWord % PERCENTAGE_RANGE < successRate) {
                    numSuccess++;
                }
            }
        }
    }
}
