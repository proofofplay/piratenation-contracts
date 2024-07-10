// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {MINTER_ROLE, MANAGER_ROLE, CURRENT_HEALTH_TRAIT_ID, HEALTH_TRAIT_ID} from "../Constants.sol";
import {ILootCallback} from "../loot/ILootCallback.sol";
import {ITraitsProvider, ID as TRAITS_PROVIDER_ID} from "../interfaces/ITraitsProvider.sol";
import {ILootCallbackV2} from "../loot/ILootCallbackV2.sol";
import {IShipNFT} from "../tokens/shipnft/IShipNFT.sol";
import {ID as SHIP_NFT_ID} from "../tokens/shipnft/ShipNFT.sol";
import {ITokenTemplateSystem, ID as TOKEN_TEMPLATE_SYSTEM_ID} from "../tokens/ITokenTemplateSystem.sol";
import {GameRegistryConsumerUpgradeable, IERC165} from "../GameRegistryConsumerUpgradeable.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.shipsystem"));

contract ShipSystem is
    GameRegistryConsumerUpgradeable,
    ILootCallback,
    ILootCallbackV2
{
    /** MEMBERS **/

    /// @notice Counter for current id of ship to mint
    uint256 public currentShipId;

    /** ERRORS **/

    /// @notice Invalid amount
    error InvalidGrantAmount();

    /// @notice Ship not found in templates
    error InvalidShipId(uint256 shipId);

    /// @notice Invalid params
    error InvalidParams();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * Updates the current ship id count
     * @param newCount      New count to set
     */
    function updateCurrentShipIdCount(
        uint256 newCount
    ) external onlyRole(MANAGER_ROLE) {
        currentShipId = newCount;
    }

    /**
     * Grants loot of Ship
     *
     * @param account       Address of the accouint to mint to
     * @param lootId        NFT template tokenId of ship to mint
     * @param amount        Amount to mint
     *
     */
    function grantLoot(
        address account,
        uint256 lootId,
        uint256 amount
    )
        external
        override(ILootCallback, ILootCallbackV2)
        onlyRole(MINTER_ROLE)
        whenNotPaused
    {
        _grantLoot(account, lootId, amount);
    }

    /** INTERNAL **/

    function _grantLoot(
        address account,
        uint256 lootId,
        uint256 amount
    ) internal {
        if (amount < 1) {
            revert InvalidGrantAmount();
        }

        IShipNFT shipNFT = IShipNFT(_getSystem(SHIP_NFT_ID));

        ITraitsProvider traitsProvider = _traitsProvider();

        address tokenTemplateSystemAddress = _getSystem(
            TOKEN_TEMPLATE_SYSTEM_ID
        );

        ITokenTemplateSystem tokenTemplateSystem = ITokenTemplateSystem(
            tokenTemplateSystemAddress
        );

        for (uint8 idx = 0; idx < amount; idx++) {
            if (!tokenTemplateSystem.exists(lootId)) {
                revert InvalidShipId(lootId);
            }

            // Increment current token id to next id
            currentShipId++;

            uint256 shipTokenId = currentShipId;

            tokenTemplateSystem.setTemplate(
                address(shipNFT),
                shipTokenId,
                lootId
            );

            shipNFT.mint(account, shipTokenId);

            // set current health to health trait max
            int256 shipHealth = traitsProvider.getTraitInt256(
                tokenTemplateSystemAddress,
                lootId,
                HEALTH_TRAIT_ID
            );

            traitsProvider.setTraitUint256(
                address(shipNFT),
                shipTokenId,
                CURRENT_HEALTH_TRAIT_ID,
                SafeCast.toUint256(shipHealth)
            );
        }
    }

    /**
     * @inheritdoc ILootCallbackV2
     */
    function grantLootWithRandomWord(
        address account,
        uint256 lootId,
        uint256 amount,
        uint256 randomWord
    ) external onlyRole(MINTER_ROLE) whenNotPaused returns (uint256) {
        _grantLoot(account, lootId, amount);
        return randomWord;
    }

    /** @return Whether or not this callback needs randomness */
    function needsVRF() external pure returns (bool) {
        return false;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165) returns (bool) {
        return interfaceId == type(ILootCallbackV2).interfaceId;
    }

    /**
     * @notice Batch migrate ships
     * @param accounts      Array of accounts to mint to
     * @param tokenIds      Array of tokenIds to mint
     * @param lootIds       Array of lootIds to mint (is the template id for the ship)
     */
    function batchMigrateShips(
        address[] calldata accounts,
        uint256[] calldata tokenIds,
        uint256[] calldata lootIds
    ) external whenNotPaused onlyRole(MANAGER_ROLE) {
        if (
            accounts.length != tokenIds.length ||
            accounts.length != lootIds.length ||
            tokenIds.length != lootIds.length
        ) {
            revert InvalidParams();
        }
        IShipNFT shipNFT = IShipNFT(_getSystem(SHIP_NFT_ID));

        ITraitsProvider traitsProvider = _traitsProvider();

        address tokenTemplateSystemAddress = _getSystem(
            TOKEN_TEMPLATE_SYSTEM_ID
        );
        ITokenTemplateSystem tokenTemplateSystem = ITokenTemplateSystem(
            tokenTemplateSystemAddress
        );
        int256 shipHealth;
        for (uint256 i = 0; i < accounts.length; i++) {
            currentShipId++;
            if (!tokenTemplateSystem.exists(lootIds[i])) {
                revert InvalidShipId(lootIds[i]);
            }
            shipNFT.mint(accounts[i], tokenIds[i]);

            tokenTemplateSystem.setTemplate(
                address(shipNFT),
                tokenIds[i],
                lootIds[i]
            );
            shipHealth = traitsProvider.getTraitInt256(
                tokenTemplateSystemAddress,
                lootIds[i],
                HEALTH_TRAIT_ID
            );
            traitsProvider.setTraitUint256(
                address(shipNFT),
                tokenIds[i],
                CURRENT_HEALTH_TRAIT_ID,
                SafeCast.toUint256(shipHealth)
            );
        }
    }
}
