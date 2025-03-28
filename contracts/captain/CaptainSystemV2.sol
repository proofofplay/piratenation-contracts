// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ICaptainSystem, ID} from "./ICaptainSystem.sol";
import {PERCENTAGE_RANGE, GAME_NFT_CONTRACT_ROLE, GAME_LOGIC_CONTRACT_ROLE, IS_PIRATE_TRAIT_ID} from "../Constants.sol";
import {CaptainComponentV2, ID as CAPTAIN_COMPONENT_ID} from "../generated/components/CaptainComponentV2.sol";
import {Uint256Component, ID as UINT256_COMPONENT_ID} from "../generated/components/Uint256Component.sol";
import {IsPirateComponent, ID as IS_PIRATE_COMPONENT_ID} from "../generated/components/IsPirateComponent.sol";
import {ID as PIRATE_NFT_ID} from "../tokens/PirateNFTL2.sol";
import {GameRegistryLibrary} from "../libraries/GameRegistryLibrary.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import "../GameRegistryConsumerUpgradeable.sol";

// Globals used by this contract
uint256 constant SET_CAPTAIN_TIMEOUT_SECS_ID = uint256(
    keccak256("game.piratenation.global.set_captain_timeout_secs")
);

/// @title CaptainSystemV2
/// System to let the player choose their captain pirate
contract CaptainSystemV2 is ICaptainSystem, GameRegistryConsumerUpgradeable {
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
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        uint256 nftEntity = EntityLibrary.tokenToEntity(tokenContract, tokenId);

        CaptainComponentV2 captainComponent = CaptainComponentV2(
            _gameRegistry.getComponent(CAPTAIN_COMPONENT_ID)
        );
        (, uint256 lastSetCaptainTime) = captainComponent.getValue(
            accountEntity
        );
        if (
            block.timestamp - lastSetCaptainTime <
            Uint256Component(_gameRegistry.getComponent(UINT256_COMPONENT_ID))
                .getValue(SET_CAPTAIN_TIMEOUT_SECS_ID)
        ) {
            revert SetCaptainInCooldown();
        }

        if (tokenContract != address(0)) {
            // Make sure NFT is properly setup
            if (
                IsPirateComponent(
                    _gameRegistry.getComponent(IS_PIRATE_COMPONENT_ID)
                ).getValue(
                        EntityLibrary.tokenToEntity(tokenContract, tokenId)
                    ) == false
            ) {
                revert IsNotPirate();
            }

            // Make sure user owns the pirate NFT
            if (IERC721(tokenContract).ownerOf(tokenId) != account) {
                revert NotOwner();
            }

            captainComponent.setValue(
                accountEntity,
                nftEntity,
                block.timestamp
            );
        } else {
            captainComponent.setValue(accountEntity, 0, lastSetCaptainTime);
        }
    }

    /** @return lastSetCaptainTime Last time captain was set */
    function getLastSetCaptainTime(
        address account
    ) external view returns (uint256) {
        uint256 entity = EntityLibrary.addressToEntity(account);
        CaptainComponentV2 captainComponent = CaptainComponentV2(
            _gameRegistry.getComponent(CAPTAIN_COMPONENT_ID)
        );
        (, uint256 lastSetCaptainTime) = captainComponent.getValue(entity);
        return lastSetCaptainTime;
    }

    /**
     * @return tokenContract        Token contract for the captain NFT
     * @return tokenId              Token id for the captain NFT
     */
    function getCaptainNFT(
        address account
    ) external view returns (address tokenContract, uint256 tokenId) {
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        CaptainComponentV2 captainComponent = CaptainComponentV2(
            _gameRegistry.getComponent(CAPTAIN_COMPONENT_ID)
        );
        (uint256 nftEntity, ) = captainComponent.getValue(accountEntity);
        (tokenContract, tokenId) = EntityLibrary.entityToToken(nftEntity);
    }
}
