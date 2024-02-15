// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {IGameGlobals, ID as GAME_GLOBALS_ID} from "../gameglobals/IGameGlobals.sol";
import {ILootCallback} from "../loot/ILootCallback.sol";
import {IGameItems, ID as GAME_ITEMS_CONTRACT_ID} from "../tokens/gameitems/IGameItems.sol";
import {GAME_LOGIC_CONTRACT_ROLE, MINTER_ROLE} from "../Constants.sol";
import {TradeLicenseComponent, ID as TRADE_LICENSE_COMPONENT_ID} from "../generated/components/TradeLicenseComponent.sol";

import {ITradeLicenseSystem, ID} from "./ITradeLicenseSystem.sol";
import {TradeableShipNFT, ID as TRADEABLE_SHIP_NFT_ID} from "../tokens/shipnft/TradeableShipNFT.sol";
import {TradeableGameItems, ID as TRADEABLE_GAME_ITEM_ID} from "../tokens/gameitems/TradeableGameItems.sol";
import {GoldTokenStrategy, ID as GOLD_TOKEN_STRATEGY_ID} from "../tokens/goldtoken/GoldTokenStrategy.sol";

// Global: TradeLicense game item id
uint256 constant TRADE_LICENSE_GAME_ITEMS_ID = uint256(
    keccak256("trade_license_game_items_id")
);

/**
 * @title TradeLicenseSystem
 */
contract TradeLicenseSystem is
    GameRegistryConsumerUpgradeable,
    ILootCallback,
    ITradeLicenseSystem
{
    /** ERRORS */

    /// @notice Trade license already granted
    error TradeLicenseAlreadyGranted();

    /// @notice No TradeLicense in wallet
    error NoTradeLicense();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /** GETTERS */

    /**
     * @dev Check if an account has a TradeLicense
     * @param account Address of the account to check
     */
    function checkHasTradeLicense(
        address account
    ) public view override returns (bool) {
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        return _checkTradeLicense(accountEntity);
    }

    /** EXTERNAL */

    /**
     * @dev User triggered function to burn a TradeLicense game item and be granted a TradeLicense
     */
    function consumeTradeLicense() public nonReentrant whenNotPaused {
        // Get user account
        address account = _getPlayerAccount(_msgSender());
        // Check if player has a TradeLicense game item in their wallet
        IGameItems gameItems = IGameItems(
            _gameRegistry.getSystem(GAME_ITEMS_CONTRACT_ID)
        );
        uint256 tradeLicenseGameItemsId = IGameGlobals(
            _gameRegistry.getSystem(GAME_GLOBALS_ID)
        ).getUint256(TRADE_LICENSE_GAME_ITEMS_ID);
        if (gameItems.balanceOf(account, tradeLicenseGameItemsId) == 0) {
            revert NoTradeLicense();
        }
        // Burn 1 TradeLicense game item
        gameItems.burn(account, tradeLicenseGameItemsId, 1);
        // Check if player already has a TradeLicense
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        if (_checkTradeLicense(accountEntity) == true) {
            revert TradeLicenseAlreadyGranted();
        }
        // Grant the player a TradeLicense
        _grantTradeLicense(account);
    }

    /**
     * @dev Grant a TradeLicense to an account, called by other systems
     * @param account Address of the account to grant a TradeLicense to
     */
    function grantTradeLicense(
        address account
    ) public override whenNotPaused onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _grantTradeLicense(account);
    }

    /** CALLBACK */

    /**
     * @dev Callback function for Lootsystem
     * @param account Address of the account to grant a TradeLicense to
     */
    function grantLoot(
        address account,
        uint256,
        uint256
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        if (_checkTradeLicense(accountEntity) == true) {
            return;
        }
        _grantTradeLicense(account);
    }

    /** INTERNAL */

    /**
     * @dev Grant a TradeLicense to an account
     * @param account Address of the account to grant a TradeLicense to
     */
    function _grantTradeLicense(address account) internal {
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        if (_checkTradeLicense(accountEntity) == true) {
            revert TradeLicenseAlreadyGranted();
        }
        TradeLicenseComponent(
            _gameRegistry.getComponent(TRADE_LICENSE_COMPONENT_ID)
        ).setValue(accountEntity, true);

        // MV: warning, big accounts could fail here initial benching says wont be a problem until we have 2k+ game items/
        TradeableShipNFT(_gameRegistry.getSystem(TRADEABLE_SHIP_NFT_ID))
            .sendEnableTradeLicenseEvents(account);

        TradeableGameItems(_gameRegistry.getSystem(TRADEABLE_GAME_ITEM_ID))
            .sendEnableTradeLicenseEvents(account);

        GoldTokenStrategy(_gameRegistry.getSystem(GOLD_TOKEN_STRATEGY_ID))
            .tradeLicenseWasEnabled(account);
    }

    /**
     * @dev Check if an account has a TradeLicense
     * @param accountEntity entity of the account to check
     */
    function _checkTradeLicense(
        uint256 accountEntity
    ) internal view returns (bool) {
        return
            TradeLicenseComponent(
                _gameRegistry.getComponent(TRADE_LICENSE_COMPONENT_ID)
            ).getValue(accountEntity);
    }
}
