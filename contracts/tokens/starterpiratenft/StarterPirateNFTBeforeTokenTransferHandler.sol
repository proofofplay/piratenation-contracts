// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import {IERC721BeforeTokenTransferHandler} from "../IERC721BeforeTokenTransferHandler.sol";
import {GameRegistryConsumerUpgradeable, ILockingSystem, ITraitsProvider} from "../../GameRegistryConsumerUpgradeable.sol";

import {EntityLibrary} from "../../core/EntityLibrary.sol";
import {HasSoulComponent, ID as HAS_SOUL_COMPONENT_ID} from "../../generated/components/HasSoulComponent.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.starterpiratenftbeforetokentransferhandler")
);

contract StarterPirateNFTBeforeTokenTransferHandler is
    GameRegistryConsumerUpgradeable,
    IERC721BeforeTokenTransferHandler
{
    /** ERRORS **/

    /// @notice Token type is soulbound to current owner and cannot be transfered
    error TokenIsSoulbound();

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
     * Before transfer hook for NFTs. Performs any trait checks needed before transfer
     *
     * @param tokenContract     Address of the token contract
     * @param firstTokenId      Id of the token to generate traits for
     * @param from              From address
     */
    function beforeTokenTransfer(
        address tokenContract,
        address, // operator
        address from,
        address to,
        uint256 firstTokenId,
        uint256 // batchSize
    ) external view {
        // Locked check if not minting
        if (from != address(0) && to != address(0)) {
            // Check if HAS_SOUL_COMPONENT is present, can burn soulbound items
            bool hasSoul = HasSoulComponent(
                _gameRegistry.getComponent(HAS_SOUL_COMPONENT_ID)
            ).getValue(
                    EntityLibrary.tokenToEntity(tokenContract, firstTokenId)
                );
            if (hasSoul == false) {
                revert TokenIsSoulbound();
            }
        }
    }
}
