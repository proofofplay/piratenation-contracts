// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import {IERC721BeforeTokenTransferHandler} from "../IERC721BeforeTokenTransferHandler.sol";
import {GameRegistryConsumerUpgradeable} from "../../GameRegistryConsumerUpgradeable.sol";
import {EntityLibrary} from "../../core/EntityLibrary.sol";
import {SoulboundComponent, ID as SOULBOUND_COMPONENT_ID} from "../../generated/components/SoulboundComponent.sol";
import {MixinComponent, ID as MIXIN_COMPONENT_ID} from "../../generated/components/MixinComponent.sol";

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

    /// @notice No mixin found
    error NoMixinFound(uint256 entityId);

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
            SoulboundComponent soulboundComponent = SoulboundComponent(
                _gameRegistry.getComponent(SOULBOUND_COMPONENT_ID)
            );
            MixinComponent mixinComponent = MixinComponent(
                _gameRegistry.getComponent(MIXIN_COMPONENT_ID)
            );
            for (uint256 idx = 0; idx < batchSize; idx++) {
                uint256 tokenId = firstTokenId + idx;
                uint256 entity = EntityLibrary.tokenToEntity(
                    tokenContract,
                    tokenId
                );
                // Get the mixin id for the ship
                uint256[] memory mixins = mixinComponent.getValue(entity);
                if (mixins.length == 0) {
                    revert NoMixinFound(entity);
                }
                uint256 mixinEntity = mixins[0];
                // Check if mixin id has soulbound component
                bool isSoulBound = soulboundComponent.getValue(mixinEntity);
                if (isSoulBound) {
                    revert TokenIsSoulbound();
                }
            }
        }
    }
}
