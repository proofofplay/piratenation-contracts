// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../randomizer/Randomizer.sol";

/** @title Mock Randomizer for testing VRF flows locally */
contract RandomizerMock is Randomizer {
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;

    Counters.Counter private _currentRequestId;

    struct VRFRequestInfo {
        uint64 numWords;
    }

    mapping(uint256 => VRFRequestInfo) requestInfo;
    EnumerableSet.UintSet private pendingRequests;

    /** ERRORS **/

    /// @notice Trying to execute invalid requestId
    error InvalidRequestId();

    /** SETUP **/
    constructor(
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId,
        address _gameRegistryAddress
    )
        Randomizer(
            _vrfCoordinator,
            _keyHash,
            _subscriptionId,
            _gameRegistryAddress
        )
    {}

    /** EXTERNAL **/

    /// @dev Returns the current request Id, can be used by tests
    function getCurrentRequestId() external view returns (uint256) {
        return _currentRequestId.current();
    }

    /// @dev Returns all pending requests
    function hasPendingRequests() external view returns (bool) {
        return pendingRequests.length() > 0;
    }

    /// @dev Execute all pending requests
    function executeAllPendingRequests() external {
        for (uint256 idx = 0; idx < pendingRequests.length(); ++idx) {
            executeRandomWordsRequest(pendingRequests.at(idx));
        }
    }

    /// Executes and fulfills a given random words request with a pseudo random number
    /// @dev this function basically satisfies the role of the VRFCoordinator
    function executeRandomWordsRequest(uint256 requestId) public {
        uint64 numWords = requestInfo[requestId].numWords;

        if (numWords == 0) {
            revert InvalidRequestId();
        }

        if (numWords > 0) {
            uint256[] memory randomWords = new uint256[](numWords);

            for (uint256 idx = 0; idx < numWords; ++idx) {
                uint256 randomness = uint256(
                    keccak256(
                        abi.encodePacked(
                            idx,
                            requestId,
                            tx.origin,
                            gasleft(),
                            block.coinbase,
                            blockhash(block.number - 1),
                            block.timestamp
                        )
                    )
                );
                randomWords[idx] = randomness;
            }

            delete requestInfo[requestId];

            fulfillRandomWords(requestId, randomWords);
            pendingRequests.remove(requestId);
        }
    }

    /// Executes and fulfills a given random words request with a specific number
    /// @dev this function basically satisfies the role of the VRFCoordinator
    function executeRandomWordsRequestWithValues(
        uint256 requestId,
        uint256[] memory randomWords
    ) external {
        uint64 numWords = requestInfo[requestId].numWords;
        if (numWords > 0) {
            delete requestInfo[requestId];

            fulfillRandomWords(requestId, randomWords);
        }
    }

    /**
     * Issues a request for random words (uint256 numbers)
     *
     * @param randomizerCallback Callback to run once the words arrive
     * @param numWords           Number of words to request
     */
    function requestRandomWords(
        IRandomizerCallback randomizerCallback,
        uint32 numWords
    ) external override onlyRole(GAME_LOGIC_CONTRACT_ROLE) returns (uint256) {
        _currentRequestId.increment();

        // Will revert if subscription is not set and funded.
        uint256 requestId = _currentRequestId.current();
        callbacks[requestId] = randomizerCallback;
        requestInfo[requestId] = VRFRequestInfo({numWords: numWords});

        pendingRequests.add(requestId);

        return requestId;
    }
}
