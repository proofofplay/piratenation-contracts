// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {MINTER_ROLE, MANAGER_ROLE} from "../Constants.sol";
import {ILootCallbackV2} from "../loot/ILootCallbackV2.sol";
import {IShipNFT} from "../tokens/shipnft/IShipNFT.sol";
import {ID as SHIP_NFT_ID} from "../tokens/shipnft/ShipNFT.sol";
import {MixinComponent, ID as MIXIN_COMPONENT_ID} from "../generated/components/MixinComponent.sol";
import {MintCounterComponent, ID as MINT_COUNTER_COMPONENT_ID} from "../generated/components/MintCounterComponent.sol";

import {IERC165, GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {TokenIdLibrary} from "../core/TokenIdLibrary.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.shipsystem.v2"));

contract ShipSystemV2 is GameRegistryConsumerUpgradeable, ILootCallbackV2 {
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
        MintCounterComponent mintCounterComponent = MintCounterComponent(
            _gameRegistry.getComponent(MINT_COUNTER_COMPONENT_ID)
        );
        mintCounterComponent.setValue(ID, newCount);
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
    ) external override(ILootCallbackV2) onlyRole(MINTER_ROLE) whenNotPaused {
        _mintAndInitializeLoot(account, lootId, amount);
    }

    /**
     * @inheritdoc ILootCallbackV2
     */
    function grantLootWithRandomWord(
        address account,
        uint256 lootId,
        uint256 amount,
        uint256 randomWord
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        _mintAndInitializeLoot(account, lootId, amount);

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
        return
            interfaceId == type(ILootCallbackV2).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    /**
     * @notice Batch mint ships with multichain tokenId support
     * @param accounts      Array of accounts to mint to
     * @param tokenIds      Array of tokenIds to mint
     * @param lootIds       Array of lootIds to mint (is the template id for the ship)
     */
    function batchMintShips(
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

        MintCounterComponent mintCounterComponent = MintCounterComponent(
            _gameRegistry.getComponent(MINT_COUNTER_COMPONENT_ID)
        );
        uint256 currentShipId = mintCounterComponent.getValue(ID);

        IShipNFT shipNFT = IShipNFT(_getSystem(SHIP_NFT_ID));
        MixinComponent mixinComponent = MixinComponent(
            _gameRegistry.getComponent(MIXIN_COMPONENT_ID)
        );
        for (uint256 i = 0; i < accounts.length; i++) {
            currentShipId++;
            _mintAndSetup(
                shipNFT,
                mixinComponent,
                accounts[i],
                tokenIds[i],
                lootIds[i]
            );
        }

        mintCounterComponent.setValue(ID, currentShipId);
    }

    /** INTERNAL **/

    function _mintAndInitializeLoot(
        address account,
        uint256 lootId,
        uint256 amount
    ) internal {
        if (amount < 1) {
            revert InvalidGrantAmount();
        }

        MintCounterComponent mintCounterComponent = MintCounterComponent(
            _gameRegistry.getComponent(MINT_COUNTER_COMPONENT_ID)
        );
        uint256 currentShipId = mintCounterComponent.getValue(ID);

        IShipNFT shipNFT = IShipNFT(_getSystem(SHIP_NFT_ID));
        MixinComponent mixinComponent = MixinComponent(
            _gameRegistry.getComponent(MIXIN_COMPONENT_ID)
        );
        for (uint8 idx = 0; idx < amount; idx++) {
            // Increment current token id to next id
            currentShipId++;
            uint96 tokenId = TokenIdLibrary.generateTokenId(currentShipId);
            _mintAndSetup(shipNFT, mixinComponent, account, tokenId, lootId);
        }

        mintCounterComponent.setValue(ID, currentShipId);
    }

    function _mintAndSetup(
        IShipNFT shipNFT,
        MixinComponent mixinComponent,
        address account,
        uint256 tokenId,
        uint256 lootId
    ) internal {
        // Set mixin component
        uint256[] memory mixins = new uint256[](1);
        mixins[0] = lootId;

        mixinComponent.setValue(
            EntityLibrary.tokenToEntity(address(shipNFT), tokenId),
            mixins
        );

        shipNFT.mint(account, tokenId);
    }
}
