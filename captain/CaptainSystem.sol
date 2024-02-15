// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ICaptainSystem, ID} from "./ICaptainSystem.sol";
import {IGameGlobals, ID as GAME_GLOBALS_ID} from "../gameglobals/IGameGlobals.sol";
import {PERCENTAGE_RANGE, GAME_NFT_CONTRACT_ROLE, GAME_LOGIC_CONTRACT_ROLE, IS_PIRATE_TRAIT_ID} from "../Constants.sol";
import {ITraitsProvider, ID as TRAITS_PROVIDER_ID} from "../interfaces/ITraitsProvider.sol";

import {GameRegistryLibrary} from "../libraries/GameRegistryLibrary.sol";
import "../GameRegistryConsumerUpgradeable.sol";

// Globals used by this contract
uint256 constant SET_CAPTAIN_TIMEOUT_SECS_ID = uint256(
    keccak256("set_captain_timeout_secs")
);

/// @title CaptainSystem
/// System to let the player choose their captain pirate
contract CaptainSystem is ICaptainSystem, GameRegistryConsumerUpgradeable {
    /// @notice The current captain for the player
    /// account => (ReservedGameNFT struct)
    mapping(address => GameRegistryLibrary.ReservedGameNFT)
        private _captainNFTs;

    /// @notice Last time the player set their captain
    mapping(address => uint256) _lastSetCaptainTime;

    /** EVENTS **/

    /// @notice Emitted when captain is changed
    event SetCaptain(
        address indexed owner,
        address indexed tokenContract,
        uint256 indexed tokenId
    );

    /** ERRORS **/

    /// @notice NFT is not a pirate NFT
    error IsNotPirate();

    /// @notice Must wait to set captain again
    error SetCaptainInCooldown();

    /// @notice Origin is not the owner of the specified NFT
    error NotOwner();

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
     * Sets the current captain NFT for the player
     *
     * @param tokenContract Address of the captain NFT
     * @param tokenId       Id of the captain NFT token
     */
    function setCaptainNFT(
        address tokenContract,
        uint256 tokenId
    ) external whenNotPaused nonReentrant {
        address account = _getPlayerAccount(_msgSender());
        IGameGlobals gameGlobals = IGameGlobals(_getSystem(GAME_GLOBALS_ID));

        if (
            block.timestamp - _lastSetCaptainTime[account] <
            gameGlobals.getUint256(SET_CAPTAIN_TIMEOUT_SECS_ID)
        ) {
            revert SetCaptainInCooldown();
        }

        GameRegistryLibrary.ReservedGameNFT storage captainNFT = _captainNFTs[
            account
        ];

        if (tokenContract != address(0)) {
            ITraitsProvider traitsProvider = ITraitsProvider(
                _getSystem(TRAITS_PROVIDER_ID)
            );

            // Make sure NFT is properly setup
            if (_isPirateNFT(traitsProvider, tokenContract, tokenId) != true) {
                revert IsNotPirate();
            }

            // Make sure user owns the pirate NFT
            if (IERC721(tokenContract).ownerOf(tokenId) != account) {
                revert NotOwner();
            }

            // Update NFT pointer
            captainNFT.tokenContract = tokenContract;
            captainNFT.tokenId = tokenId;

            // Emit event
            emit SetCaptain(account, tokenContract, tokenId);

            // Track cooldown timer if a captain was set
            _lastSetCaptainTime[account] = block.timestamp;
        } else {
            // Update NFT pointer to null
            captainNFT.tokenContract = address(0);
            captainNFT.tokenId = 0;

            // Emit event
            emit SetCaptain(account, address(0), 0);
        }
    }

    /** @return lastSetCaptainTime Last time captain was set */
    function getLastSetCaptainTime(
        address account
    ) external view returns (uint256) {
        return _lastSetCaptainTime[account];
    }

    /**
     * @return tokenContract        Token contract for the captain NFT
     * @return tokenId              Token id for the captain NFT
     */
    function getCaptainNFT(
        address account
    ) external view returns (address tokenContract, uint256 tokenId) {
        GameRegistryLibrary.ReservedGameNFT storage nft = _captainNFTs[account];
        tokenContract = nft.tokenContract;
        tokenId = nft.tokenId;
    }

    /** INTERNAL/PRIVATE **/

    /** Verify NFT is a pirate **/
    function _isPirateNFT(
        ITraitsProvider traitsProvider,
        address tokenContract,
        uint256 tokenId
    ) internal view returns (bool) {
        return
            _hasAccessRole(GAME_NFT_CONTRACT_ROLE, tokenContract) &&
            traitsProvider.hasTrait(tokenContract, tokenId, IS_PIRATE_TRAIT_ID);
    }
}
