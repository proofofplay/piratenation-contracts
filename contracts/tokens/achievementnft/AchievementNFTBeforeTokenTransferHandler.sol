// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import {IERC721BeforeTokenTransferHandler} from "../IERC721BeforeTokenTransferHandler.sol";
import {GameRegistryConsumerUpgradeable, ILockingSystem, ITraitsProvider} from "../../GameRegistryConsumerUpgradeable.sol";
import {SOULBOUND_TRAIT_ID} from "../../Constants.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.achievementbeforetokentransferhandler")
);

contract AchievementNFTBeforeTokenTransferHandler is
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
     * @param to                To address
     * @param batchSize         Size of the batch transfer
     */
    function beforeTokenTransfer(
        address tokenContract,
        address, // operator
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) external view {
        // Soulbound check if not minting
        // Can burn soulbound items
        if (from != address(0) && to != address(0)) {
            ITraitsProvider traitsProvider = _traitsProvider();
            for (uint256 idx = 0; idx < batchSize; idx++) {
                uint256 tokenId = firstTokenId + idx;
                if (
                    traitsProvider.hasTrait(
                        tokenContract,
                        tokenId,
                        SOULBOUND_TRAIT_ID
                    ) &&
                    traitsProvider.getTraitBool(
                        tokenContract,
                        tokenId,
                        SOULBOUND_TRAIT_ID
                    ) ==
                    true
                ) {
                    revert TokenIsSoulbound();
                }
            }
        }
    }
}
