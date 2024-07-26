// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import {IERC1155BeforeTokenTransferHandler} from "../IERC1155BeforeTokenTransferHandler.sol";
import {GameRegistryConsumerUpgradeable, ITraitsProvider} from "../../GameRegistryConsumerUpgradeable.sol";
import {SOULBOUND_TRAIT_ID} from "../../Constants.sol";
import {EntityLibrary} from "../../core/EntityLibrary.sol";
import {BanComponent, ID as BAN_COMPONENT_ID} from "../../generated/components/BanComponent.sol";
import {TradeLicenseComponent, Layout as TradeLicenseComponentStruct, ID as TRADE_LICENSE_COMPONENT_ID} from "../../generated/components/TradeLicenseComponent.sol";
import {TradeLicenseExemptComponent, Layout as TradeLicenseExemptComponentStruct, ID as TRADE_LICENSE_EXEMPT_COMPONENT_ID} from "../../generated/components/TradeLicenseExemptComponent.sol";
import {TradeLibrary} from "../../trade/TradeLibrary.sol";
import {TradeLicenseChecks} from "../TradeLicenseChecks.sol";
import {ID as GAME_ITEMS_ID} from "./IGameItems.sol";
import {TradeableGameItems, ID as TRADEABLE_GAME_ITEMS_ID} from "./TradeableGameItems.sol";
import {Banned} from "../../ban/BanSystem.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.gameitemsbeforetokentransferhandler")
);

contract GameItemsBeforeTokenTransferHandler is
    GameRegistryConsumerUpgradeable,
    IERC1155BeforeTokenTransferHandler
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
     * Before transfer hook for GameItems. Performs any trait checks needed before transfer
     *
     * @param tokenContract     Address of the token contract
     * @param from              From address
     * @param ids               Ids to transfer
     * @param amounts           Amounts to transfer
     */
    function beforeTokenTransfer(
        address tokenContract,
        address, // operator
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory // data
    ) external {
        if (from != address(0)) {
            // Check if user is banned
            if (
                BanComponent(_gameRegistry.getComponent(BAN_COMPONENT_ID))
                    .getValue(EntityLibrary.addressToEntity(from)) == true
            ) {
                revert Banned();
            }

            // Can burn soulbound items
            if (to != address(0)) {
                // If sender is not burning, check if sender wallet has TradeLicense and each game item.
                // Revert if no TradeLicense found and any item is not exempt.
                bool hasTradeLicense = TradeLibrary.hasTradeLicense(
                    TradeLicenseComponent(
                        _gameRegistry.getComponent(TRADE_LICENSE_COMPONENT_ID)
                    ),
                    EntityLibrary.addressToEntity(from)
                );
                TradeLicenseExemptComponent tleComponent = TradeLicenseExemptComponent(
                        _gameRegistry.getComponent(
                            TRADE_LICENSE_EXEMPT_COMPONENT_ID
                        )
                    );

                ITraitsProvider traitsProvider = _traitsProvider();
                for (uint8 idx; idx < ids.length; ++idx) {
                    bool isExempt = tleComponent.getValue(
                        EntityLibrary.tokenToEntity(
                            _gameRegistry.getSystem(GAME_ITEMS_ID),
                            ids[idx]
                        )
                    );

                    // If no trade license and game item is not exempt, revert
                    if (!hasTradeLicense && !isExempt) {
                        revert TradeLibrary.MissingTradeLicense();
                    }

                    // Can burn soulbound items
                    uint256 tokenId = ids[idx];
                    // Soulbound check
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

        TradeableGameItems tradeableGameItems = TradeableGameItems(
            _gameRegistry.getSystem(TRADEABLE_GAME_ITEMS_ID)
        );

        if (address(tradeableGameItems) != address(0)) {
            tradeableGameItems.emitTransferEvent(from, to, ids, amounts);
        }
    }
}
