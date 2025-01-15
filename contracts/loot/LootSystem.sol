// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {VRF_SYSTEM_ROLE, MANAGER_ROLE, GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";

import {ILootSystem, ID} from "./ILootSystem.sol";
import {IGameNFTLoot} from "../tokens/gamenft/IGameNFTLoot.sol";
import {ILootCallback} from "./ILootCallback.sol";
import {IGameItems} from "../tokens/gameitems/IGameItems.sol";
import {IGameCurrency} from "../tokens/IGameCurrency.sol";

import "../libraries/RandomLibrary.sol";
import "../GameRegistryConsumerUpgradeable.sol";

// @title A loot table system
contract LootSystem is ILootSystem, GameRegistryConsumerUpgradeable {
    /** STRUCTS **/
    struct LootTable {
        // All of the loots for this table
        Loot[][] loots;
        // Probability weight of each loot
        uint32[] weights;
        // How many of each loots are available in this table (0 = unlimited)
        uint32[] maxSupply;
        // How many of each loot has been minted
        uint32[] mints;
        // Pre-calculated total weight to save gas later
        // TODO: Shift this to AJ Walker Alias Algo
        uint256 totalWeight;
    }

    // Struct to track and respond to VRF requests
    struct VRFRequest {
        // Account the request is for
        address account;
        // Loot to grant
        Loot[] loots;
    }

    /** MEMBERS **/

    /// @notice Loot table id to loot table data
    mapping(uint256 => LootTable) private _lootTables;

    /// @notice Mapping to track VRF requests
    mapping(uint256 => VRFRequest) private vrfRequests;

    /// @notice Null loot, used to return / grant nothing
    Loot _nullLoot;

    /** EVENTS **/

    /// @notice Emit when a loot table has been updated
    event LootTableUpdated(uint256 indexed lootTableId);

    /** ERRORS */

    /// @notice Loot data doesn't match expectations
    error LootArrayMismatch();

    /// @notice Loot array is too large
    error LootArrayTooLarge();

    /// @notice No support for tested loot tables currently
    error NoNestedLootTables();

    /// @notice Contract address not properly set for loot type
    error InvalidContractAddress(
        ILootSystem.LootType lootType,
        address contractAddress
    );

    /// @notice Loot amount not properly set
    error InvalidLootAmount();

    /// @notice Expected non-zero random word for loot table
    error InvalidRandomWord();

    /// @notice Missing loots for loot table
    error NoLootsForLootTable(uint256 lootTableId);

    /// @notice Invalid loot type specified
    error InvalidLootType(ILootSystem.LootType lootType);

    /** SETUP **/

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
        _nullLoot = Loot({
            lootType: LootType.UNDEFINED,
            amount: 0,
            tokenContract: address(0),
            lootId: 0
        });
    }

    /** EXTERNAL **/

    /**
     * Setup a loot table
     *
     * @param lootTableId  Id of the loot table
     * @param loots        Loots in the table
     * @param weights      Weights for each of the loots in the table
     * @param maxSupply    Maximum amount of each loot available
     */
    function setLootTable(
        uint256 lootTableId,
        Loot[][] calldata loots,
        uint32[] calldata weights,
        uint32[] calldata maxSupply
    ) external onlyRole(MANAGER_ROLE) {
        if (
            loots.length != weights.length || loots.length != maxSupply.length
        ) {
            revert LootArrayMismatch();
        }

        if (loots.length > 0xFFFF) {
            revert LootArrayTooLarge();
        }

        LootTable storage lootTable = _lootTables[lootTableId];

        delete lootTable.loots;

        uint256 total;
        for (uint16 idx; idx < loots.length; ++idx) {
            Loot[] memory lootSet = loots[idx];

            // Add new element to storage array
            lootTable.loots.push();

            Loot[] storage storageSet = lootTable.loots[idx];

            for (uint16 setIdx; setIdx < lootSet.length; ++setIdx) {
                if (lootSet[setIdx].lootType == LootType.LOOT_TABLE) {
                    revert NoNestedLootTables();
                }
                _validateLoot(lootSet[setIdx]);
                storageSet.push(lootSet[setIdx]);
            }
            total += weights[idx];
        }

        lootTable.totalWeight = total;
        lootTable.weights = weights;
        lootTable.maxSupply = maxSupply;

        // Initialize array if it hasn't been already
        if (lootTable.mints.length != loots.length) {
            lootTable.mints = new uint32[](loots.length);
        }

        emit LootTableUpdated(lootTableId);
    }

    /**
     * @inheritdoc ILootSystem
     */
    function grantLoot(
        address to,
        Loot[] calldata loots
    ) external override nonReentrant onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        // See if we need to use VRF to properly grant from loot table
        bool needVRF;
        for (uint8 idx; idx < loots.length; ++idx) {
            if (loots[idx].lootType == LootType.LOOT_TABLE) {
                needVRF = true;
                break;
            }
        }

        if (needVRF) {
            uint256 requestId = _requestRandomNumber(0);
            VRFRequest storage request = vrfRequests[requestId];
            request.account = to;
            for (uint8 idx; idx < loots.length; ++idx) {
                request.loots.push(loots[idx]);
            }
        } else {
            // This is only valid if there are no loot-tables being granted
            _finishGrantLoot(to, loots, 0);
        }
    }

    /**
     * @inheritdoc ILootSystem
     */
    function batchGrantLootWithoutRandomness(
        address to,
        Loot[] calldata loots,
        uint8 amount
    ) external nonReentrant onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        for (uint8 idx; idx < loots.length; ++idx) {
            Loot memory loot = loots[idx];
            if (loot.lootType == LootType.LOOT_TABLE) {
                revert InvalidLootType(loot.lootType);
            } else {
                _mintLoot(to, loot, loot.amount * amount);
            }
        }
    }

    /**
     * @inheritdoc ILootSystem
     */
    function grantLootWithRandomWord(
        address to,
        Loot[] calldata loots,
        uint256 randomWord
    ) external override nonReentrant onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        _finishGrantLoot(to, loots, randomWord);
    }

    /**
     * @param lootTableId  Loot table to retrieve
     */
    function getLootTable(
        uint256 lootTableId
    ) external view returns (LootTable memory) {
        return _lootTables[lootTableId];
    }

    /**
     * Finish granting loot using randomness from VRF
     * @inheritdoc GameRegistryConsumerUpgradeable
     */
    function randomNumberCallback(
        uint256 requestId,
        uint256 randomNumber
    ) external override onlyRole(VRF_SYSTEM_ROLE) {
        VRFRequest storage request = vrfRequests[requestId];
        address account = request.account;

        if (account != address(0)) {
            _finishGrantLoot(account, request.loots, randomNumber);

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
        for (uint16 idx; idx < loots.length; ++idx) {
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
            interfaceId == type(ILootSystem).interfaceId ||
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

        if (loot.lootType == LootType.ERC20) {
            if (loot.tokenContract == address(0)) {
                revert InvalidContractAddress(
                    loot.lootType,
                    loot.tokenContract
                );
            }
        } else if (loot.lootType == LootType.ERC721) {
            if (loot.tokenContract == address(0)) {
                revert InvalidContractAddress(
                    loot.lootType,
                    loot.tokenContract
                );
            }
        } else if (loot.lootType == LootType.ERC1155) {
            if (loot.tokenContract == address(0)) {
                revert InvalidContractAddress(
                    loot.lootType,
                    loot.tokenContract
                );
            }
        } else if (loot.lootType == LootType.LOOT_TABLE) {
            if (loot.tokenContract != address(0)) {
                revert InvalidContractAddress(
                    loot.lootType,
                    loot.tokenContract
                );
            }
            LootTable storage lootTable = _lootTables[loot.lootId];
            if (lootTable.loots.length == 0) {
                revert NoLootsForLootTable(loot.lootId);
            }
            needsVRF = true;
        } else if (loot.lootType == LootType.CALLBACK) {
            if (loot.tokenContract == address(0)) {
                revert InvalidContractAddress(
                    loot.lootType,
                    loot.tokenContract
                );
            }
            // TODO: make sure the address implements ILootCallback
        } else {
            revert InvalidLootType(loot.lootType);
        }
    }

    // Finishing granting loot to the player using randomness
    function _finishGrantLoot(
        address to,
        Loot[] memory loots,
        uint256 randomWord
    ) private {
        for (uint8 idx; idx < loots.length; ++idx) {
            Loot memory loot = loots[idx];
            if (loot.lootType == LootType.LOOT_TABLE) {
                if (randomWord == 0) {
                    revert InvalidRandomWord();
                }

                LootTable storage lootTable = _lootTables[loot.lootId];
                for (uint8 count; count < loot.amount; ++count) {
                    randomWord = RandomLibrary.generateNextRandomWord(
                        randomWord
                    );
                    Loot[] memory lootSet = _pickLoot(lootTable, randomWord);
                    for (uint8 setIdx; setIdx < lootSet.length; ++setIdx) {
                        Loot memory lootSetLoot = lootSet[setIdx];
                        _mintLoot(to, lootSetLoot, lootSetLoot.amount);
                    }
                }
            } else {
                _mintLoot(to, loot, loot.amount);
            }
        }
    }

    // Pick a random loot set from a loot table
    function _pickLoot(
        LootTable storage lootTable,
        uint256 randomWord
    ) private returns (Loot[] memory) {
        // It's possible for a loot table to have no items available, in which case we just return null loot
        if (lootTable.totalWeight == 0) {
            Loot[] memory lootSet;
            return lootSet;
        }

        // Get a random number between 0 - totalWeight
        uint256 entropy = randomWord % lootTable.totalWeight;

        // Find the item that corresponds with that number

        // TODO: Switch this to AJ Walker Alias Algorithm to make it O(1)
        uint256 total = 0;
        for (uint16 idx; idx < lootTable.loots.length; ++idx) {
            total += lootTable.weights[idx];
            if (entropy < total) {
                // Increment number of mints for the given idx
                lootTable.mints[idx]++;

                // See if we need to recalculate total weight and remove item once from the loot table once supply has run out
                if (lootTable.mints[idx] == lootTable.maxSupply[idx]) {
                    lootTable.weights[idx] = 0;
                    _calculateTotalWeight(lootTable);
                }

                return lootTable.loots[idx];
            }
        }

        return lootTable.loots[lootTable.loots.length - 1];
    }

    // Calculates total weight and stores it for the loot table
    function _calculateTotalWeight(LootTable storage lootTable) private {
        uint32 total = 0;
        for (uint16 idx; idx < lootTable.weights.length; ++idx) {
            total += lootTable.weights[idx];
        }
        lootTable.totalWeight = total;
    }

    // Performs the mint for the loot
    function _mintLoot(address to, Loot memory loot, uint256 amount) private {
        if (loot.lootType == LootType.ERC20) {
            IGameCurrency(loot.tokenContract).mint(to, amount);
        } else if (loot.lootType == LootType.ERC1155) {
            IGameItems(loot.tokenContract).mint(
                to,
                SafeCast.toUint32(loot.lootId),
                amount
            );
        } else if (loot.lootType == LootType.ERC721) {
            IGameNFTLoot(loot.tokenContract).mintBatch(
                to,
                SafeCast.toUint8(amount)
            );
        } else if (loot.lootType == LootType.CALLBACK) {
            ILootCallback(loot.tokenContract).grantLoot(
                to,
                loot.lootId,
                amount
            );
        } else if (loot.lootType == LootType.UNDEFINED) {
            // Do nothing, NOOP
            return;
        } else {
            revert InvalidLootType(loot.lootType);
        }
    }
}
