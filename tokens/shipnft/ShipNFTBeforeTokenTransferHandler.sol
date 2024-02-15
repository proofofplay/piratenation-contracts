// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import {IERC721BeforeTokenTransferHandler} from "../IERC721BeforeTokenTransferHandler.sol";
import {GameRegistryConsumerUpgradeable, ILockingSystem, ITraitsProvider} from "../../GameRegistryConsumerUpgradeable.sol";
import {SOULBOUND_TRAIT_ID} from "../../Constants.sol";
import {ITokenTemplateSystem, ID as TOKEN_TEMPLATE_SYSTEM_ID} from "../../tokens/ITokenTemplateSystem.sol";
import {TradeableShipNFT, ID as TRADEABLE_SHIP_NFT} from "./TradeableShipNFT.sol";
import {TradeLicenseComponent, Layout as TradeLicenseComponentStruct, ID as TRADE_LICENSE_COMPONENT_ID} from "../../generated/components/TradeLicenseComponent.sol";
import {TradeLibrary} from "../../trade/TradeLibrary.sol";
import {EntityLibrary} from "../../core/EntityLibrary.sol";

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
        // Locked check if not minting
        if (from != address(0)) {
            ILockingSystem lockingSystem = _lockingSystem();
            for (uint256 idx = 0; idx < batchSize; idx++) {
                if (
                    lockingSystem.isNFTLocked(
                        tokenContract,
                        firstTokenId + idx
                    ) == true
                ) {
                    revert IsLocked();
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
                ITokenTemplateSystem tokenTemplateSystem = ITokenTemplateSystem(
                    _getSystem(TOKEN_TEMPLATE_SYSTEM_ID)
                );

                for (uint256 idx = 0; idx < batchSize; idx++) {
                    uint256 tokenId = firstTokenId + idx;
                    // Soulbound check if not minting
                    if (
                        tokenTemplateSystem.hasTrait(
                            tokenContract,
                            tokenId,
                            SOULBOUND_TRAIT_ID
                        ) &&
                        abi.decode(
                            tokenTemplateSystem.getTraitBytes(
                                tokenContract,
                                tokenId,
                                SOULBOUND_TRAIT_ID
                            ),
                            (bool)
                        ) ==
                        true
                    ) {
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
