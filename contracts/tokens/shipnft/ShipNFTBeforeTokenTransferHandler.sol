// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import {IERC721BeforeTokenTransferHandler} from "../IERC721BeforeTokenTransferHandler.sol";
import {GameRegistryConsumerUpgradeable} from "../../GameRegistryConsumerUpgradeable.sol";
import {TradeableShipNFT, ID as TRADEABLE_SHIP_NFT} from "./TradeableShipNFT.sol";
import {TradeLicenseComponent, Layout as TradeLicenseComponentStruct, ID as TRADE_LICENSE_COMPONENT_ID} from "../../generated/components/TradeLicenseComponent.sol";
import {TradeLibrary} from "../../trade/TradeLibrary.sol";
import {EntityLibrary} from "../../core/EntityLibrary.sol";
import {BanComponent, ID as BAN_COMPONENT_ID} from "../../generated/components/BanComponent.sol";
import {SoulboundComponent, ID as SOULBOUND_COMPONENT_ID} from "../../generated/components/SoulboundComponent.sol";
import {MixinComponent, ID as MIXIN_COMPONENT_ID} from "../../generated/components/MixinComponent.sol";
import {Banned} from "../../ban/BanSystem.sol";
import {SkinContainerComponent, Layout as SkinContainerComponentLayout, ID as SKIN_CONTAINER_COMPONENT_ID} from "../../generated/components/SkinContainerComponent.sol";
import {SHIP_SKIN_GUID} from "../../skin/ShipSkinSystem.sol";
import {IGameItems, ID as GAME_ITEMS_CONTRACT_ID} from "../gameitems/IGameItems.sol";
import {ItemsEquippedComponent, ID as ITEMS_EQUIPPED_COMPONENT_ID} from "../../generated/components/ItemsEquippedComponent.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.shipnftbeforetokentransferhandler")
);

contract ShipNFTBeforeTokenTransferHandler is
    GameRegistryConsumerUpgradeable,
    IERC721BeforeTokenTransferHandler
{
    /** ERRORS **/

    /// @notice Token is locked and cannot be transferred
    error IsLocked();

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
     * @param batchSize         Size of the batch transfer
     */
    function beforeTokenTransfer(
        address tokenContract,
        address, // operator
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) external {
        SkinContainerComponentLayout memory skinContainerLayout;
        ItemsEquippedComponent itemsEquippedComponent = ItemsEquippedComponent(
            _gameRegistry.getComponent(ITEMS_EQUIPPED_COMPONENT_ID)
        );
        for (uint256 idx = 0; idx < batchSize; idx++) {
            uint256 tokenId = firstTokenId + idx;
            uint256 entity = EntityLibrary.tokenToEntity(
                tokenContract,
                tokenId
            );

            // Remove all equipped items from the ship
            if (itemsEquippedComponent.has(entity)) {
                itemsEquippedComponent.remove(entity);
            }
        }
        // Locked check if not minting
        if (from != address(0)) {
            // Is not banned
            if (
                BanComponent(_gameRegistry.getComponent(BAN_COMPONENT_ID))
                    .getValue(EntityLibrary.addressToEntity(from)) == true
            ) {
                revert Banned();
            }
            uint256[] memory mixins;
            SoulboundComponent soulboundComponent = SoulboundComponent(
                _gameRegistry.getComponent(SOULBOUND_COMPONENT_ID)
            );

            for (uint256 idx = 0; idx < batchSize; idx++) {
                uint256 tokenId = firstTokenId + idx;
                uint256 entity = EntityLibrary.tokenToEntity(
                    tokenContract,
                    tokenId
                );
                skinContainerLayout = SkinContainerComponent(
                    _gameRegistry.getComponent(SKIN_CONTAINER_COMPONENT_ID)
                ).getLayoutValue(entity);
                // Mint equipped skin back to user
                for (
                    uint256 i = 0;
                    i < skinContainerLayout.slotEntities.length;
                    i++
                ) {
                    if (skinContainerLayout.slotEntities[i] == SHIP_SKIN_GUID) {
                        (
                            address itemTokenContract,
                            uint256 itemTokenId
                        ) = EntityLibrary.entityToToken(
                                skinContainerLayout.skinEntities[i]
                            );
                        IGameItems(itemTokenContract).mint(
                            from,
                            itemTokenId,
                            1
                        );
                        SkinContainerComponent(
                            _gameRegistry.getComponent(
                                SKIN_CONTAINER_COMPONENT_ID
                            )
                        ).removeValueAtIndex(entity, i);
                    }
                }
            }

            // Can burn soulbound items
            if (to != address(0)) {
                // If sender is not burning, check if sender wallet has TradeLicense, revert if no TradeLicense found
                TradeLibrary.checkTradeLicense(
                    TradeLicenseComponent(
                        _gameRegistry.getComponent(TRADE_LICENSE_COMPONENT_ID)
                    ),
                    EntityLibrary.addressToEntity(from)
                );

                for (uint256 idx = 0; idx < batchSize; idx++) {
                    uint256 tokenId = firstTokenId + idx;
                    uint256 entity = EntityLibrary.tokenToEntity(
                        tokenContract,
                        tokenId
                    );
                    // Get the mixin id for the ship
                    mixins = MixinComponent(
                        _gameRegistry.getComponent(MIXIN_COMPONENT_ID)
                    ).getValue(entity);
                    if (mixins.length == 0) {
                        revert NoMixinFound(entity);
                    }
                    // Check if mixin id has soulbound component
                    bool isSoulBound = soulboundComponent.getValue(mixins[0]);
                    if (isSoulBound) {
                        revert TokenIsSoulbound();
                    }
                }
            }
        }

        TradeableShipNFT tradeableShipNFT = TradeableShipNFT(
            _gameRegistry.getSystem(TRADEABLE_SHIP_NFT)
        );

        if (address(tradeableShipNFT) != address(0)) {
            tradeableShipNFT.emitTransferEvent(
                from,
                to,
                firstTokenId,
                batchSize
            );
        }
    }
}
