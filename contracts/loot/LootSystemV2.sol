// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {RANDOMIZER_ROLE, MANAGER_ROLE, GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";

import {ILootSystemV2, ID} from "./ILootSystemV2.sol";
import {IGameNFTLoot} from "../tokens/gamenft/IGameNFTLoot.sol";
import {ILootCallbackV2} from "./ILootCallbackV2.sol";
import {IGameItems} from "../tokens/gameitems/IGameItems.sol";
import {IGameCurrency} from "../tokens/IGameCurrency.sol";
import {LootEntityArrayComponent, Layout as LootEntityArrayComponentLayout, ID as LOOT_ENTITY_ARRAY_COMPONENT_ID} from "../generated/components/LootEntityArrayComponent.sol";
import {LootTableComponent, Layout as LootTableComponentLayout, ID as LOOT_TABLE_COMPONENT_ID} from "../generated/components/LootTableComponent.sol";
import {MintCounterComponent, ID as MINT_COUNTER_COMPONENT_ID} from "../generated/components/MintCounterComponent.sol";
import {LootTableTotalWeightComponent, ID as LOOT_TABLE_TOTAL_WEIGHT_COMPONENT_ID} from "../generated/components/LootTableTotalWeightComponent.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {RandomLibrary} from "../libraries/RandomLibrary.sol";
import {GameRegistryConsumerUpgradeable, IERC165} from "../GameRegistryConsumerUpgradeable.sol";

// @title A loot table system
contract LootSystemV2 is ILootSystemV2, GameRegistryConsumerUpgradeable {
    // Struct to track and respond to VRF requests
    struct VRFRequest {
        // Account the request is for
        address account;
        // Loot to grant
        Loot[] loots;
    }

    /** MEMBERS **/

    /// @notice Mapping to track VRF requests
    mapping(uint256 => VRFRequest) private vrfRequests;

    /** ERRORS */

    /// @notice Contract address not properly set for loot type
    error InvalidContractAddress(
        ILootSystemV2.LootType lootType,
        address contractAddress
    );

    /// @notice Token ID not properly set for loot type
    error InvalidTokenId(ILootSystemV2.LootType lootType, uint256 tokenId);

    /// @notice Loot amount not properly set
    error InvalidLootAmount();

    /// @notice Expected non-zero random word for loot table
    error InvalidRandomWord();

    /// @notice Missing loots for loot table
    error NoLootsForLootTable(uint256 lootTableEntity);

    /// @notice Invalid loot type specified
    error InvalidLootType(ILootSystemV2.LootType lootType);

    /// @notice Loot requires randomness
    error LootRequiresRandomness(ILootSystemV2.LootType lootType);

    /// @notice Error when loot picking weights are off
    error UnableToPickLoot(uint256 lootTableEntity);

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
     * @inheritdoc ILootSystemV2
     */
    function grantLoot(
        address to,
        Loot[] calldata loots
    ) external override nonReentrant onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        // See if we need to use VRF to properly grant from loot table
        bool needVRF;
        uint256 idx;
        for (idx = 0; idx < loots.length; ++idx) {
            if (loots[idx].lootType == LootType.LOOT_TABLE) {
                needVRF = true;
                break;
            } else if (loots[idx].lootType == LootType.CALLBACK) {
                (address tokenContract, ) = EntityLibrary.entityToToken(
                    loots[idx].lootEntity
                );
                if (ILootCallbackV2(tokenContract).needsVRF()) {
                    needVRF = true;
                    break;
                }
            }
        }

        if (needVRF) {
            uint256 requestId = _requestRandomWords(1);
            VRFRequest storage request = vrfRequests[requestId];
            request.account = to;
            for (idx = 0; idx < loots.length; ++idx) {
                request.loots.push(loots[idx]);
            }
        } else {
            // This is only valid if there are no loot-tables or callbacks being granted
            _finishGrantLoot(to, loots, 0);
        }
    }

    /**
     * @inheritdoc ILootSystemV2
     */
    function batchGrantLootWithoutRandomness(
        address to,
        Loot[] calldata loots,
        uint16 amount
    ) external nonReentrant onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        for (uint256 idx; idx < loots.length; ++idx) {
            Loot memory loot = loots[idx];

            // Loot tables require randomness
            if (loot.lootType == LootType.LOOT_TABLE) {
                revert LootRequiresRandomness(loot.lootType);
            } else if (loot.lootType == LootType.CALLBACK) {
                (address tokenContract, uint256 lootId) = EntityLibrary
                    .entityToToken(loot.lootEntity);
                ILootCallbackV2 callback = ILootCallbackV2(tokenContract);
                if (callback.needsVRF()) {
                    revert LootRequiresRandomness(loot.lootType);
                }
                callback.grantLoot(to, lootId, loot.amount * amount);
            } else {
                _mintLoot(to, loot, loot.amount * amount);
            }
        }
    }

    /**
     * @inheritdoc ILootSystemV2
     */
    function grantLootWithRandomWord(
        address to,
        Loot[] calldata loots,
        uint256 randomWord
    ) external override nonReentrant onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _finishGrantLoot(to, loots, randomWord);
    }

    /**
     * Finish granting loot using randomness from VRF
     * @inheritdoc GameRegistryConsumerUpgradeable
     */
    function fulfillRandomWordsCallback(
        uint256 requestId,
        uint256[] memory randomWords
    ) external override onlyRole(RANDOMIZER_ROLE) {
        VRFRequest storage request = vrfRequests[requestId];
        address account = request.account;

        if (account != address(0)) {
            _finishGrantLoot(account, request.loots, randomWords[0]);

            // Delete the VRF request
            delete vrfRequests[requestId];
        }
    }

    /**
     * Validate that loots are properly formed. Reverts if the loots are not valid
     *
     * @param loots Loots to validate
     * @return needsVRF Whether or not the loots specified require VRF to generate
     */
    function validateLoots(
        Loot[] calldata loots
    ) external view returns (bool needsVRF) {
        for (uint256 idx; idx < loots.length; ++idx) {
            Loot memory loot = loots[idx];
            bool lootNeedsVRF = _validateLoot(loot);
            needsVRF = needsVRF || lootNeedsVRF;
        }
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165) returns (bool) {
        return
            interfaceId == type(ILootSystemV2).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    /** PRIVATE **/

    // Validates that a loot is properly formed
    function _validateLoot(
        Loot memory loot
    ) internal view returns (bool needsVRF) {
        if (loot.amount == 0) {
            revert InvalidLootAmount();
        }

        ILootSystemV2.LootType lootType = loot.lootType;
        if (lootType == LootType.ERC20) {
            (address tokenContract, uint256 tokenId) = EntityLibrary
                .entityToToken(loot.lootEntity);
            if (tokenContract == address(0)) {
                revert InvalidContractAddress(lootType, tokenContract);
            }
            if (tokenId != 0) {
                revert InvalidTokenId(lootType, tokenId);
            }
        } else if (lootType == LootType.ERC721) {
            (address tokenContract, ) = EntityLibrary.entityToToken(
                loot.lootEntity
            );
            if (tokenContract == address(0)) {
                revert InvalidContractAddress(lootType, tokenContract);
            }
        } else if (lootType == LootType.ERC1155) {
            (address tokenContract, uint256 tokenId) = EntityLibrary
                .entityToToken(loot.lootEntity);
            if (tokenContract == address(0)) {
                revert InvalidContractAddress(lootType, tokenContract);
            }
            if (tokenId == 0) {
                revert InvalidTokenId(lootType, tokenId);
            }
        } else if (lootType == LootType.LOOT_TABLE) {
            (LootTableComponentLayout memory lootTable, ) = _getLootTable(
                loot.lootEntity
            );
            if (lootTable.lootEntities.length == 0) {
                revert NoLootsForLootTable(loot.lootEntity);
            }
            needsVRF = true;
        } else if (lootType == LootType.CALLBACK) {
            (address tokenContract, ) = EntityLibrary.entityToToken(
                loot.lootEntity
            );
            if (
                tokenContract == address(0) ||
                IERC165(tokenContract).supportsInterface(
                    type(ILootCallbackV2).interfaceId
                ) ==
                false
            ) {
                revert InvalidContractAddress(lootType, tokenContract);
            }

            needsVRF = ILootCallbackV2(tokenContract).needsVRF();
        } else {
            revert InvalidLootType(lootType);
        }
    }

    // Finishing granting loot to the player using randomness
    function _finishGrantLoot(
        address to,
        Loot[] memory loots,
        uint256 randomWord
    ) private {
        for (uint256 idx; idx < loots.length; ++idx) {
            Loot memory loot = loots[idx];
            if (loot.lootType == LootType.LOOT_TABLE) {
                if (randomWord == 0) {
                    revert InvalidRandomWord();
                }

                _pickAndMintLoot(to, loot.lootEntity, randomWord, loot.amount);
            } else if (loot.lootType == LootType.CALLBACK) {
                (address tokenContract, uint256 lootId) = EntityLibrary
                    .entityToToken(loot.lootEntity);
                ILootCallbackV2 callback = ILootCallbackV2(tokenContract);
                if (callback.needsVRF()) {
                    if (randomWord == 0) {
                        revert InvalidRandomWord();
                    }

                    callback.grantLootWithRandomness(
                        to,
                        lootId,
                        loot.amount,
                        randomWord
                    );
                } else {
                    callback.grantLoot(to, lootId, loot.amount);
                }
            } else {
                _mintLoot(to, loot, loot.amount);
            }
        }
    }

    /**
     * Pick and mint a random loot set from a loot table
     *
     * @param to Address to mint to
     * @param lootTableEntity Loot table entity
     * @param randomWord Random word to use for picking
     * @param quantity Number of times to pick and loot
     */
    function _pickAndMintLoot(
        address to,
        uint256 lootTableEntity,
        uint256 randomWord,
        uint256 quantity
    ) private {
        (
            LootTableComponentLayout memory lootTable,
            LootTableComponent lootTableComponent
        ) = _getLootTable(lootTableEntity);

        (
            uint256 totalWeight,
            LootTableTotalWeightComponent totalWeightComponent
        ) = _getTotalWeight(lootTable, lootTableEntity);

        MintCounterComponent mintCounterComponent = MintCounterComponent(
            _gameRegistry.getComponent(MINT_COUNTER_COMPONENT_ID)
        );

        uint256 total;
        uint256 lootToMint;
        uint256 numEntries = lootTable.lootEntities.length;
        bool needToUpdateLootTable;

        for (uint256 mintIdx; mintIdx < quantity; ++mintIdx) {
            // If there's nothing to mint, return
            if (totalWeight == 0) {
                break;
            }

            total = 0;
            lootToMint = 0;

            // Get a random number between 0 - totalWeight
            randomWord = RandomLibrary.generateNextRandomWord(randomWord);
            uint256 entropy = randomWord % totalWeight;

            // Find the item that corresponds with that number

            // TODO: Switch this to AJ Walker Alias Algorithm to make it O(1)

            for (uint256 idx; idx < numEntries; ++idx) {
                total += lootTable.weights[idx];
                if (entropy < total) {
                    uint256 lootEntity = lootTable.lootEntities[idx];
                    uint256 maxSupply = lootTable.maxSupply[idx];

                    // Increment mint counter
                    uint256 mintCounter = mintCounterComponent.getValue(
                        lootEntity
                    );
                    mintCounter++;
                    mintCounterComponent.setValue(lootEntity, mintCounter);

                    // See if we need to recalculate total weight and remove item once from the loot table once supply has run out
                    // Max supply of 0 is infinite.
                    if (
                        maxSupply > 0 && mintCounter >= lootTable.maxSupply[idx]
                    ) {
                        lootTable.weights[idx] = 0;
                        totalWeight = _calculateTotalWeight(lootTable);
                        needToUpdateLootTable = true;
                    }

                    lootToMint = lootEntity;
                    break;
                }
            }

            // This should NEVER happen
            if (lootToMint == 0) {
                revert UnableToPickLoot(lootTableEntity);
            }

            _mintLootArray(to, _getLootEntityArray(lootToMint));
        }

        if (needToUpdateLootTable) {
            // Update loot table
            lootTableComponent.setLayoutValue(lootTableEntity, lootTable);

            // Update total weight
            totalWeightComponent.setValue(lootTableEntity, totalWeight);
        }
    }

    function _getTotalWeight(
        LootTableComponentLayout memory lootTable,
        uint256 lootTableEntity
    ) private returns (uint256, LootTableTotalWeightComponent) {
        LootTableTotalWeightComponent lootTableTotalWeightComponent = LootTableTotalWeightComponent(
                _gameRegistry.getComponent(LOOT_TABLE_TOTAL_WEIGHT_COMPONENT_ID)
            );

        // If we haven't calculated total weight yet, do so now.
        if (lootTableTotalWeightComponent.has(lootTableEntity) == false) {
            lootTableTotalWeightComponent.setValue(
                lootTableEntity,
                _calculateTotalWeight(lootTable)
            );
        }

        return (
            lootTableTotalWeightComponent.getValue(lootTableEntity),
            lootTableTotalWeightComponent
        );
    }

    // Calculates total weight and stores it for the loot table
    function _calculateTotalWeight(
        LootTableComponentLayout memory lootTable
    ) private pure returns (uint256) {
        uint256 total = 0;
        for (uint256 idx; idx < lootTable.weights.length; ++idx) {
            total += lootTable.weights[idx];
        }
        return total;
    }

    // Performs the mint for the loot
    function _mintLoot(address to, Loot memory loot, uint256 amount) private {
        if (loot.lootType == LootType.ERC20) {
            (address tokenContract, ) = EntityLibrary.entityToToken(
                loot.lootEntity
            );
            IGameCurrency(tokenContract).mint(to, amount);
        } else if (loot.lootType == LootType.ERC1155) {
            (address tokenContract, uint256 tokenId) = EntityLibrary
                .entityToToken(loot.lootEntity);
            IGameItems(tokenContract).mint(to, tokenId, amount);
        } else if (loot.lootType == LootType.ERC721) {
            (address tokenContract, ) = EntityLibrary.entityToToken(
                loot.lootEntity
            );
            IGameNFTLoot(tokenContract).mintBatch(to, SafeCast.toUint8(amount));
        } else if (loot.lootType == LootType.UNDEFINED) {
            // Do nothing, NOOP
            return;
        } else {
            revert InvalidLootType(loot.lootType);
        }
    }

    function _mintLootArray(
        address to,
        LootEntityArrayComponentLayout memory lootEntityArray
    ) private {
        Loot memory loot;
        uint256 amount;
        for (uint256 idx; idx < lootEntityArray.lootEntity.length; ++idx) {
            amount = lootEntityArray.amount[idx];
            loot = Loot({
                lootType: LootType(lootEntityArray.lootType[idx]),
                lootEntity: lootEntityArray.lootEntity[idx],
                amount: amount
            });
            _mintLoot(to, loot, amount);
        }
    }

    function _getLootTable(
        uint256 lootTableEntity
    )
        private
        view
        returns (
            LootTableComponentLayout memory lootTable,
            LootTableComponent lootTableComponent
        )
    {
        lootTableComponent = LootTableComponent(
            _gameRegistry.getComponent(LOOT_TABLE_COMPONENT_ID)
        );
        lootTable = lootTableComponent.getLayoutValue(lootTableEntity);
    }

    function _getLootEntityArray(
        uint256 lootEntity
    ) private view returns (LootEntityArrayComponentLayout memory) {
        return
            LootEntityArrayComponent(
                _gameRegistry.getComponent(LOOT_ENTITY_ARRAY_COMPONENT_ID)
            ).getLayoutValue(lootEntity);
    }
}
