// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {GAME_LOGIC_CONTRACT_ROLE, RANDOMIZER_ROLE} from "../Constants.sol";
import {IRandomizer, ID} from "./IRandomizer.sol";
import {GameRegistryConsumer} from "../GameRegistryConsumer.sol";
import {IPopVRF} from "./IPopVRF.sol";
import {IPopVRFConsumer} from "./IPopVRFConsumer.sol";
import {IRandomizerCallback} from "./IRandomizerCallback.sol";

/**
 * Random number generator based off of Proof of Play VRF
 */
contract PopRandomizer is
    IRandomizer,
    ERC165,
    IPopVRFConsumer,
    GameRegistryConsumer
{
    IPopVRF private _vrf;
    /// @notice Callback registry for requests
    mapping(uint256 => IRandomizerCallback) internal callbacks;

    /** ERRORS **/
    error InvalidNumWords(uint256 expected, uint256 actual);
    error InvalidRequestId();

    /** SETUP **/

    /**
     * @param _vrfCoordinator       address of the VRF Coordinator
     * @param _gameRegistryAddress  Address of the game registry contract
     */
    constructor(
        address _vrfCoordinator,
        address _gameRegistryAddress
    ) GameRegistryConsumer(_gameRegistryAddress, ID) {
        _vrf = IPopVRF(_vrfCoordinator);
    }

    /**
     * Issues a request for random words (uint256 numbers)
     *
     * @param randomizerCallback Callback to run once the words arrive
     * @param numWords           Number of words to request (note: Kenshi only supports 1 random word at a time)
     */
    function requestRandomWords(
        IRandomizerCallback randomizerCallback,
        uint32 numWords
    )
        external
        virtual
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (uint256)
    {
        if (numWords != 1) {
            revert InvalidNumWords(1, numWords);
        }

        uint256 requestId = _vrf.request();
        callbacks[requestId] = randomizerCallback;

        return requestId;
    }

    /**
     * @param requestId Id of the request to check
     * @return Whether or not a request with the given requestId is pending
     */
    function isRequestPending(uint256 requestId) external view returns (bool) {
        return address(callbacks[requestId]) != address(0);
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, ERC165) returns (bool) {
        return
            interfaceId == type(IRandomizer).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * Callback for when the randomness process has completed
     * Called by only VRFs that have the RANDOMIZER_ROLE
     *
     * @param requestId   Id of the randomness request
     * @param randomNumber  Number generated by VRF
     */
    function recievedRandomNumber(
        uint256 requestId,
        uint256 randomNumber
    ) public override onlyRole(RANDOMIZER_ROLE) {
        IRandomizerCallback callbackAddress = callbacks[requestId];
        // Make sure request is valid and then callback
        if (address(callbackAddress) != address(0)) {
            uint256[] memory words = new uint256[](1);
            words[0] = randomNumber;

            callbackAddress.fulfillRandomWordsCallback(requestId, words);
            delete callbacks[requestId];
        } else {
            revert InvalidRequestId();
        }
    }
}
