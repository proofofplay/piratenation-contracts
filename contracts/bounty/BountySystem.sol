// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../GameRegistryConsumerUpgradeable.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";

import {RANDOMIZER_ROLE, MANAGER_ROLE, IS_PIRATE_TRAIT_ID, GENERATION_TRAIT_ID} from "../Constants.sol";

import {IGameItems} from "../tokens/gameitems/IGameItems.sol";
import {IGameCurrency} from "../tokens/IGameCurrency.sol";
import {ITraitsProvider, ID as TRAITS_PROVIDER_ID} from "../interfaces/ITraitsProvider.sol";
import {ILevelSystem, ID as LEVEL_SYSTEM_ID} from "../level/ILevelSystem.sol";
import {ILootSystem} from "../loot/ILootSystem.sol";
import {ICaptainSystem, ID as CAPTAIN_SYSTEM_ID} from "../captain/ICaptainSystem.sol";
import {IBountySystem, ID} from "./IBountySystem.sol";
import {ICooldownSystem, ID as COOLDOWN_SYSTEM_ID} from "../cooldown/ICooldownSystem.sol";
import {CountingSystem, ID as COUNTING_SYSTEM} from "../counting/CountingSystem.sol";

import {BountyComponent, ID as BOUNTY_COMPONENT_ID} from "../generated/components/BountyComponent.sol";
import {LootSetComponent, ID as LOOT_SET_COMPONENT_ID} from "../generated/components/LootSetComponent.sol";
import {ActiveBountyComponent, ID as ACTIVE_BOUNTY_COMPONENT_ID} from "../generated/components/ActiveBountyComponent.sol";
import {BountyAccountDataComponent, ID as BOUNTY_ACCOUNT_DATA_COMPONENT_ID} from "../generated/components/BountyAccountDataComponent.sol";
import {EnabledComponent, ID as ENABLED_COMPONENT_ID} from "../generated/components/EnabledComponent.sol";
import {NFTActiveBountyComponent, Layout as NFTActiveBountyComponentStruct, ID as NFT_ACTIVE_BOUNTY_COMPONENT_ID} from "../generated/components/NFTActiveBountyComponent.sol";
import {GenerationCheckComponent, Layout as GenerationCheckComponentStruct, ID as GENERATION_CHECK_COMPONENT_ID} from "../generated/components/GenerationCheckComponent.sol";

// Cooldown System ID for Bounty System cooldowns
uint256 constant BOUNTY_SYSTEM_NFT_COOLDOWN_ID = uint256(
    keccak256("bounty_system.nft.cooldown_id")
);

// Counting System ID for Bounty System counting as key for ActiveBounty counting
uint256 constant BOUNTY_SYSTEM_ACTIVE_BOUNTY_COUNTER = uint256(
    keccak256("bounty_system.active_bounty.counter")
);

// BountyLootInput : define rules for a Bounty related Loot, primarily its GUID, and loot
struct BountyLootInput {
    // Bounty Loot Component GUID
    uint256 lootEntity;
    uint32[] lootType;
    address[] tokenContract;
    uint256[] lootId;
    uint256[] amount;
}

// SetBountyInputParam : define rules for a Bounty, its Bounty Subs, its enabled status, its input loot, and its timelock
struct SetBountyInputParam {
    // Bounty ID
    uint256 bountyId;
    // Bounty Group ID
    uint256 bountyGroupId;
    // Amount of XP earned on successful completion of this Bounty
    uint32 successXp;
    // Lower bound of staked amount required for reward
    uint32 lowerBound;
    // Upper bound of staked amount required for reward
    uint32 upperBound;
    // Amount of time (in seconds) to complete this Bounty + NFTs are locked for
    uint32 bountyTimeLock;
    // Input Loot to burn to start the bounty
    BountyLootInput inputLoot;
    // Bounty Base loot
    BountyLootInput outputLoot;
}

contract BountySystem is IBountySystem, GameRegistryConsumerUpgradeable {
    /** STRUCTS */

    // VRFRequest: Struct to track and respond to VRF requests
    struct VRFRequest {
        // Account the request is for
        address account;
        // Bounty ID for the request
        uint256 bountyId;
        // Active Bounty ID for the request
        uint256 activeBountyId;
    }

    /** ENUMS */

    // Status of an active bounty
    enum ActiveBountyStatus {
        UNDEFINED,
        IN_PROGRESS,
        COMPLETED
    }

    /** MEMBERS */

    /// @notice Mapping to track VRF requests
    mapping(uint256 => VRFRequest) private _vrfRequests;

    /** EVENTS */

    /// @notice Emitted when a Bounty has been started
    event BountyStarted(
        address account,
        uint256 bountyId,
        uint256 activeBountyId
    );

    /// @notice Emitted when a Bounty has been completed
    event BountyCompleted(
        address account,
        uint256 bountyId,
        uint256 bountyGroupId,
        uint256 activeBountyId,
        bool success
    );

    /** ERRORS */

    /// @notice Error when missing inputs
    error MissingInputs();

    /// @notice Error when invalid inputs
    error InvalidInputs();

    /// @notice Error when caller is not NFT owner
    error NotNFTOwner();

    /// @notice Error when NFT not Pirate
    error NotPirateNFT();

    /// @notice NFT still in Bounty cooldown
    error NFTOnCooldown(uint256 entity);

    /// @notice Error when Bounty not in progress
    error BountyNotInProgress();

    /// @notice Error Bounty still running
    error BountyStillRunning();

    /// @notice Error when Bounty not enabled
    error BountyNotEnabled();

    /// @notice Error caller is not owner of ActiveBounty
    error BountyNotOwnedByCaller();

    /// @notice Error when invalid generation
    error InvalidGeneration();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /** SETTERS */

    /**
     * Sets the definition for a given Bounty
     * @param definition Definition for the bounty
     */
    function setBountyDefinition(
        SetBountyInputParam calldata definition,
        bool enabled,
        GenerationCheckComponentStruct calldata genCheck
    ) external onlyRole(MANAGER_ROLE) {
        // Run validation on Bounty definition
        _validateSetBountyInput(definition);
        // Set Bounty component with unique Bounty GUID
        BountyComponent(_gameRegistry.getComponent(BOUNTY_COMPONENT_ID))
            .setValue(
                definition.bountyId,
                definition.successXp,
                definition.lowerBound,
                definition.upperBound,
                definition.bountyTimeLock,
                definition.bountyGroupId,
                definition.inputLoot.lootEntity,
                definition.outputLoot.lootEntity
            );
        // Set Bounty InputLoot component with unique Bounty InputLoot GUID
        LootSetComponent(_gameRegistry.getComponent(LOOT_SET_COMPONENT_ID))
            .setValue(
                definition.inputLoot.lootEntity,
                definition.inputLoot.lootType,
                definition.inputLoot.tokenContract,
                definition.inputLoot.lootId,
                definition.inputLoot.amount
            );
        // Set Bounty Base reward Loot component with unique Bounty Base reward Loot GUID
        LootSetComponent(_gameRegistry.getComponent(LOOT_SET_COMPONENT_ID))
            .setValue(
                definition.outputLoot.lootEntity,
                definition.outputLoot.lootType,
                definition.outputLoot.tokenContract,
                definition.outputLoot.lootId,
                definition.outputLoot.amount
            );
        // Set Bounty enabled status
        EnabledComponent(_gameRegistry.getComponent(ENABLED_COMPONENT_ID))
            .setValue(definition.bountyId, enabled);
        // Set GenerationCheckComponent
        GenerationCheckComponent(
            _gameRegistry.getComponent(GENERATION_CHECK_COMPONENT_ID)
        ).setLayoutValue(definition.bountyGroupId, genCheck);
    }

    /**
     * @dev Set the Bounty status for a given Bounty Group
     * @param bountyGroupId Bounty Group ID
     * @param enabled Bounty enabled status
     */
    function setBountyStatus(
        uint256 bountyGroupId,
        bool enabled
    ) external override onlyRole(MANAGER_ROLE) {
        // Set Bounty enabled status
        EnabledComponent(_gameRegistry.getComponent(ENABLED_COMPONENT_ID))
            .setValue(bountyGroupId, enabled);
    }

    /** GETTERS */

    /**
     * @dev Get list of active bounty ids for a given account
     * @return All active bounty ids for a given account
     */
    function activeBountyIdsForAccount(
        address account
    ) external view override returns (uint256[] memory) {
        BountyAccountDataComponent accountDataComponent = BountyAccountDataComponent(
                _gameRegistry.getComponent(BOUNTY_ACCOUNT_DATA_COMPONENT_ID)
            );
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        (, uint256[] memory activeBountyIds) = accountDataComponent.getValue(
            accountEntity
        );

        return activeBountyIds;
    }

    /**
     * @dev Check if a Bounty is available to a user wallet
     * @param account Account to check if Bounty is available for
     * @param bountyId Id of the Bounty to see is available
     * @return Whether or not the Bounty is available to the given account
     */
    function isBountyAvailable(
        address account,
        uint256 bountyId
    ) public view override returns (bool) {
        (, , , , uint256 groupId, , ) = BountyComponent(
            _gameRegistry.getComponent(BOUNTY_COMPONENT_ID)
        ).getValue(bountyId);

        if (!EnabledComponent(
            _gameRegistry.getComponent(ENABLED_COMPONENT_ID)
        ).getValue(bountyId)) {
            return false;
        }

        // If user has a pending bounty for this Bounty type, return false
        if (hasPendingBounty(account, groupId)) {
            return false;
        }
        return true;
    }

    /**
     * @dev Return boolean if a user has a pending bounty for a given Bounty type
     * @param account Account to check
     * @param bountyGroupId Group Id of the Bounty to check
     * @return Whether or not the user has a pending bounty for the given Bounty type
     */
    function hasPendingBounty(
        address account,
        uint256 bountyGroupId
    ) public view override returns (bool) {
        // The CountingSystem entity is Bounty ID and key is User Wallet
        if (
            CountingSystem(_gameRegistry.getSystem(COUNTING_SYSTEM)).getCount(
                bountyGroupId,
                EntityLibrary.addressToEntity(account)
            ) > 0
        ) {
            return true;
        }
        return false;
    }

    /** CLIENT FUNCTIONS */

    /**
     * Starts a Bounty for a user
     * @param bountyId entity ID of the bounty to start
     * @param entities Inputs to the bounty, these should only be the NFTs in entity format
     */
    function startBounty(
        uint256 bountyId,
        uint256[] calldata entities
    ) public nonReentrant whenNotPaused returns (uint256) {
        if (bountyId == 0 || entities.length == 0) {
            revert InvalidInputs();
        }
        // Get user account
        address account = _getPlayerAccount(_msgSender());
        // Get Bounty component for this bounty
        (
            ,
            uint32 lowerBound,
            uint32 upperBound,
            uint32 bountyTimeLock,
            uint256 groupId,
            uint256 inputLootId,

        ) = BountyComponent(_gameRegistry.getComponent(BOUNTY_COMPONENT_ID))
                .getValue(bountyId);
        // Check that amount of NFTs is within bounds
        if (entities.length < lowerBound || entities.length > upperBound) {
            revert InvalidInputs();
        }

        // Verify startBounty call inputs and conditions on user
        _verifyStartBounty(account, bountyId, groupId, bountyTimeLock);

        // Create an ActiveBounty
        uint256 activeBountyId = _createActiveBounty(
            account,
            bountyId,
            groupId,
            entities
        );

        // Verift ownership, verify NFT IS_PIRATE, check and set NftActiveBountyComponent
        _verifyNftInputs(account, entities, activeBountyId, groupId);

        // Handle burning the entry requirements for this bounty
        _handleBurningInputs(account, inputLootId);

        // Add active bounty id to users accountdata, user wallet is the unique GUID
        _addToAccountData(account, activeBountyId);

        emit BountyStarted(account, bountyId, activeBountyId);

        return activeBountyId;
    }

    /**
     * Ends a bounty for a user
     * @param activeBountyId ID of the active bounty to end
     */
    function endBounty(
        uint256 activeBountyId
    ) public nonReentrant whenNotPaused {
        // Get user account
        address account = _getPlayerAccount(_msgSender());

        // Validate endBounty() call : Check that the bounty is active, account is the owner, and timelock has passed
        _validateEndBounty(account, activeBountyId);

        // Check that user still owns the NFTs that were staked for the bounty
        bool failedBounty = _checkStakedNfts(account, activeBountyId);
        if (failedBounty) {
            // User failed the bounty, mark as complete, do not dispense rewards
            _handleFailedBounty(account, activeBountyId);
        } else {
            // Handle loot rewards for a completed Bounty
            _handleLoot(account, activeBountyId);
        }
    }

    /**
     * Finishes Bounty with randomness, VRF callback func
     */
    function fulfillRandomWordsCallback(
        uint256 requestId,
        uint256[] memory randomWords
    ) external override onlyRole(RANDOMIZER_ROLE) {
        VRFRequest storage request = _vrfRequests[requestId];
        if (request.account != address(0)) {
            // Get the BountySub component associated with this request
            (
                uint32 successXp,
                ,
                ,
                ,
                uint256 groupId,
                ,
                uint256 baseLootId
            ) = BountyComponent(_gameRegistry.getComponent(BOUNTY_COMPONENT_ID))
                    .getValue(request.bountyId);

            uint256 randomWord = randomWords[0];
            ILootSystem lootSystem = _lootSystem();

            // Convert baseloot to ILootSystem.Loot
            ILootSystem.Loot[] memory baseRewardLoot = _convertLootSet(
                baseLootId
            );

            // Grant baseloot
            lootSystem.grantLootWithRandomWord(
                request.account,
                baseRewardLoot,
                randomWord
            );

            // Grant successXp
            _handleXp(successXp, request.activeBountyId);

            // Emit BountyCompleted event
            emit BountyCompleted(
                request.account,
                request.bountyId,
                groupId,
                request.activeBountyId,
                true
            );

            // Delete the VRF request
            delete _vrfRequests[requestId];
        }
    }

    /** INTERNAL **/

    /**
     * @dev Add the ActiveBounty GUID to the users account data
     * @param account Account to add the ActiveBounty GUID to
     * @param activeBountyId ActiveBounty GUID to add to the users account data
     */
    function _addToAccountData(
        address account,
        uint256 activeBountyId
    ) internal {
        // Add active bounty id to users accountdata, user wallet is the unique GUID
        BountyAccountDataComponent accountDataComponent = BountyAccountDataComponent(
                _gameRegistry.getComponent(BOUNTY_ACCOUNT_DATA_COMPONENT_ID)
            );
        uint256 localEntity = EntityLibrary.addressToEntity(account);
        (, uint256[] memory activeBountyIds) = accountDataComponent.getValue(
            localEntity
        );
        uint256[] memory newActiveBountyIds = new uint256[](
            activeBountyIds.length + 1
        );
        for (uint256 i = 0; i < activeBountyIds.length; i++) {
            newActiveBountyIds[i] = activeBountyIds[i];
        }
        newActiveBountyIds[activeBountyIds.length] = activeBountyId;
        accountDataComponent.setValue(localEntity, account, newActiveBountyIds);
    }

    /**
     * @dev Remove the ActiveBounty GUID from the users account data
     * @param account Account to remove the ActiveBounty GUID from
     * @param activeBountyId GUID of the ActiveBounty to remove
     */
    function _removeFromAccountData(
        address account,
        uint256 activeBountyId
    ) internal {
        BountyAccountDataComponent accountDataComponent = BountyAccountDataComponent(
                _gameRegistry.getComponent(BOUNTY_ACCOUNT_DATA_COMPONENT_ID)
            );
        uint256 localEntity = EntityLibrary.addressToEntity(account);
        (, uint256[] memory activeBountyIds) = accountDataComponent.getValue(
            localEntity
        );

        uint256[] memory newActiveBountyIds = new uint256[](
            activeBountyIds.length - 1
        );
        uint256 lastIndex = activeBountyIds[activeBountyIds.length - 1];
        for (uint256 i = 0; i < activeBountyIds.length - 1; i++) {
            if (activeBountyIds[i] == activeBountyId) {
                newActiveBountyIds[i] = lastIndex;
            } else {
                newActiveBountyIds[i] = activeBountyIds[i];
            }
        }

        accountDataComponent.setValue(localEntity, account, newActiveBountyIds);
    }

    /**
     * @dev Handle a failed Bounty
     */
    function _handleFailedBounty(
        address account,
        uint256 activeBountyId
    ) internal {
        // Set ActiveBounty status to COMPLETED
        // Get ActiveBounty component for the users active bounty
        (, , , uint256 bountyId, uint256 groupId, ) = ActiveBountyComponent(
            _gameRegistry.getComponent(ACTIVE_BOUNTY_COMPONENT_ID)
        ).getValue(activeBountyId);
        _setActiveBountyCompleted(account, activeBountyId);
        emit BountyCompleted(account, bountyId, groupId, activeBountyId, false);
    }

    /**
     * Handles loot for a bounty ending, checks bonus table and triggers VRF if needed
     */
    function _handleLoot(address account, uint256 activeBountyId) internal {
        // Get user ActiveBounty component
        (, , , uint256 bountyId, , ) = ActiveBountyComponent(
            _gameRegistry.getComponent(ACTIVE_BOUNTY_COMPONENT_ID)
        ).getValue(activeBountyId);
        // Get the Bounty component associated with this bounty
        (
            uint32 successXp,
            ,
            ,
            ,
            uint256 groupId,
            ,
            uint256 baseLootId
        ) = BountyComponent(_gameRegistry.getComponent(BOUNTY_COMPONENT_ID))
                .getValue(bountyId);

        // Convert base loot to ILootSystem.Loot
        ILootSystem.Loot[] memory baseRewardLoot = _convertLootSet(baseLootId);
        ILootSystem lootSystem = _lootSystem();
        // If your base reward loot requires VRF OR bonusloot exists then request VRF, else immediately award base loot
        if (lootSystem.validateLoots(baseRewardLoot)) {
            // Request VRF
            VRFRequest storage vrfRequest = _vrfRequests[
                _requestRandomWords(1)
            ];
            vrfRequest.account = account;
            vrfRequest.bountyId = bountyId;
            vrfRequest.activeBountyId = activeBountyId;
        } else {
            // No VRF needed for baseloot and no bonusloot, just handle base reward loot and successXp
            lootSystem.grantLoot(account, baseRewardLoot);
            _handleXp(successXp, activeBountyId);
            // Emit BountyCompleted event
            emit BountyCompleted(
                account,
                bountyId,
                groupId,
                activeBountyId,
                true
            );
        }
        // Set ActiveBounty status to COMPLETED
        _setActiveBountyCompleted(account, activeBountyId);
    }

    /**
     * @dev Set ActiveBounty component status to COMPLETED and set the pending bounty count to 0
     * @param account UserAccount
     * @param activeBountyId ID of the active bounty to end
     */
    function _setActiveBountyCompleted(
        address account,
        uint256 activeBountyId
    ) internal {
        // Remove this ActiveBounty guid from the users account data
        _removeFromAccountData(account, activeBountyId);
        // Get ActiveBounty component for the users active bounty
        ActiveBountyComponent activeBounty = ActiveBountyComponent(
            _gameRegistry.getComponent(ACTIVE_BOUNTY_COMPONENT_ID)
        );
        // Get ActiveBounty component for the users active bounty
        (
            ,
            ,
            uint32 startTime,
            uint256 bountyId,
            uint256 groupId,
            uint256[] memory entityInputs
        ) = activeBounty.getValue(activeBountyId);
        // Set ActiveBountyComponent with status to COMPLETED
        activeBounty.setValue(
            activeBountyId,
            uint32(ActiveBountyStatus.COMPLETED),
            account,
            startTime,
            bountyId,
            groupId,
            entityInputs
        );
        // Set pending bounty count to 0 for this Bounty type
        CountingSystem(_gameRegistry.getSystem(COUNTING_SYSTEM)).setCount(
            groupId,
            EntityLibrary.addressToEntity(account),
            0
        );
    }

    /**
     * @dev Check that user still owns the NFTs that were staked for the bounty
     * @param account Account to check
     * @param activeBountyId ID of the active bounty to check
     */
    function _checkStakedNfts(
        address account,
        uint256 activeBountyId
    ) internal returns (bool) {
        bool failedBounty;
        // Get user ActiveBounty component
        (, , , , , uint256[] memory entityInputs) = ActiveBountyComponent(
            _gameRegistry.getComponent(ACTIVE_BOUNTY_COMPONENT_ID)
        ).getValue(activeBountyId);
        // Check that user still owns all the NFTs they staked for the bounty
        uint256 tokenId;
        address tokenContract;
        NFTActiveBountyComponent nftActiveBountyComponent = NFTActiveBountyComponent(
                _gameRegistry.getComponent(NFT_ACTIVE_BOUNTY_COMPONENT_ID)
            );
        for (uint256 i = 0; i < entityInputs.length; ++i) {
            (tokenContract, tokenId) = EntityLibrary.entityToToken(
                entityInputs[i]
            );
            NFTActiveBountyComponentStruct
                memory nftActiveBounty = nftActiveBountyComponent
                    .getLayoutValue(entityInputs[i]);
            // Get NFT current owner address
            address nftOwner = IERC721(tokenContract).ownerOf(tokenId);
            if (nftActiveBounty.shouldCheckNft == true) {
                // If activeBountyId matches and caller is owner then clear the component
                if (
                    activeBountyId == nftActiveBounty.activeBountyId &&
                    account == nftOwner
                ) {
                    nftActiveBountyComponent.setLayoutValue(
                        entityInputs[i],
                        NFTActiveBountyComponentStruct(0, address(0), true)
                    );
                } else {
                    // Otherwise mark bounty as failed
                    failedBounty = true;
                }
            } else {
                // Only verify ownership
                if (account != nftOwner) {
                    failedBounty = true;
                }
            }
        }
        return failedBounty;
    }

    /**
     * Validate EndBounty call
     * @dev Check caller, check status, check time lock
     * @param userAccount Account to check
     * @param activeBountyId ID of the active bounty to check
     */
    function _validateEndBounty(
        address userAccount,
        uint256 activeBountyId
    ) internal view {
        (
            uint32 status,
            address account,
            uint32 startTime,
            uint256 bountyId,
            ,

        ) = ActiveBountyComponent(
                _gameRegistry.getComponent(ACTIVE_BOUNTY_COMPONENT_ID)
            ).getValue(activeBountyId);
        // Check if user is the account that created the bounty
        if (userAccount != account) {
            revert BountyNotOwnedByCaller();
        }
        // Check if bounty is in progress
        if (status != uint32(ActiveBountyStatus.IN_PROGRESS)) {
            revert BountyNotInProgress();
        }
        // Get Bounty component and check if bounty is valid to end
        (, , , uint32 bountyTimeLock, , , ) = BountyComponent(
            _gameRegistry.getComponent(BOUNTY_COMPONENT_ID)
        ).getValue(bountyId);

        // Check if Bounty valid to end
        if (block.timestamp < startTime + bountyTimeLock) {
            revert BountyStillRunning();
        }
    }

    /**
     * Create an ActiveBounty component using a local entity counter to get a counter
     * and then use that counter to create an ActiveBounty component GUID entity(local address, counter)
     * @param account The account associated with the ActiveBounty
     * @param bountyId The ID of the Bounty component
     * @param entities The entities of the NFTs that were staked for the bounty
     */
    function _createActiveBounty(
        address account,
        uint256 bountyId,
        uint256 groupId,
        uint256[] calldata entities
    ) internal returns (uint256) {
        // Create a local entity counter, Increment counter by 1 and get the latest counter for bounties
        uint256 localEntity = EntityLibrary.addressToEntity(address(this));
        CountingSystem countingSystem = CountingSystem(
            _gameRegistry.getSystem(COUNTING_SYSTEM)
        );
        countingSystem.incrementCount(
            localEntity,
            BOUNTY_SYSTEM_ACTIVE_BOUNTY_COUNTER,
            1
        );
        uint256 latestCounterValue = countingSystem.getCount(
            localEntity,
            BOUNTY_SYSTEM_ACTIVE_BOUNTY_COUNTER
        );

        // The ActiveBounty ID is the local address + latest counter value
        uint256 activeBountyId = EntityLibrary.tokenToEntity(
            address(this),
            latestCounterValue
        );

        // Set ActiveBountyComponent
        ActiveBountyComponent(
            _gameRegistry.getComponent(ACTIVE_BOUNTY_COMPONENT_ID)
        ).setValue(
                activeBountyId,
                uint32(ActiveBountyStatus.IN_PROGRESS),
                account,
                SafeCast.toUint32(block.timestamp),
                bountyId,
                groupId,
                entities
            );
        return activeBountyId;
    }

    /**
     * Handles the burning of input loots for a bounty
     * @param account The account that is burning the input loots
     * @param inputLootSetId The component GUID of the input loots
     */
    function _handleBurningInputs(
        address account,
        uint256 inputLootSetId
    ) internal {
        // Get the input loots
        (
            uint32[] memory lootType,
            address[] memory tokenContract,
            uint256[] memory lootId,
            uint256[] memory amount
        ) = LootSetComponent(_gameRegistry.getComponent(LOOT_SET_COMPONENT_ID))
                .getValue(inputLootSetId);
        // Revert if no entry loots found
        if (lootType.length == 0) {
            revert InvalidInputs();
        }
        for (uint256 i = 0; i < lootType.length; ++i) {
            if (lootType[i] == uint32(ILootSystem.LootType.ERC20)) {
                // Burn amount of ERC20 tokens required to start this bounty
                IGameCurrency(tokenContract[i]).burn(account, amount[i]);
            } else if (lootType[i] == uint32(ILootSystem.LootType.ERC1155)) {
                // Burn amount of ERC1155 tokens required to start this bounty
                IGameItems(tokenContract[i]).burn(
                    account,
                    lootId[i],
                    amount[i]
                );
            }
        }
    }

    /**
     * Verifies inputs and checks related to starting a bounty
     * @param account The account that is starting the bounty
     * @param bountyId The ID of the Bounty
     */
    function _verifyStartBounty(
        address account,
        uint256 bountyId,
        uint256 groupId,
        uint32 timeLock
    ) internal {
        // Check if bounty is enabled or available for this user
        if (isBountyAvailable(account, bountyId) == false) {
            revert BountyNotEnabled();
        }
        // Add a cooldown on this User Wallet + Bounty Component Group ID to ensure user can only run 1 type of this Bounty at a time
        if (
            ICooldownSystem(_getSystem(COOLDOWN_SYSTEM_ID))
                .updateAndCheckCooldown(
                    EntityLibrary.addressToEntity(account),
                    groupId,
                    timeLock
                )
        ) {
            revert BountyStillRunning();
        }
        // Increment the users count for this Bounty type (group id) by 1
        CountingSystem(_gameRegistry.getSystem(COUNTING_SYSTEM)).incrementCount(
                groupId,
                EntityLibrary.addressToEntity(account),
                1
            );
    }

    /**
     * Verify valid NFT inputs for staking : User is owner, token is IS_PIRATE, token is not on cooldown, apply cooldown on token
     * @param account User account
     * @param entityNfts Array of entity NFTs to verify
     * @param activeBountyId ID of the active bounty
     * @param bountyGroupId Group ID of the bounty
     */
    function _verifyNftInputs(
        address account,
        uint256[] calldata entityNfts,
        uint256 activeBountyId,
        uint256 bountyGroupId
    ) internal {
        NFTActiveBountyComponent nftActiveBountyComponent = NFTActiveBountyComponent(
                _gameRegistry.getComponent(NFT_ACTIVE_BOUNTY_COMPONENT_ID)
            );
        GenerationCheckComponentStruct
            memory generationCheckComponent = GenerationCheckComponent(
                _gameRegistry.getComponent(GENERATION_CHECK_COMPONENT_ID)
            ).getLayoutValue(bountyGroupId);
        ITraitsProvider traitsProvider = _traitsProvider();
        for (uint256 i = 0; i < entityNfts.length; ++i) {
            // Check Pirate NFT
            _checkPirateNft(
                traitsProvider,
                generationCheckComponent,
                entityNfts[i],
                account
            );
            // Set NftActiveBountyComponent
            _checkAndSetNftActiveBountyComponent(
                nftActiveBountyComponent,
                entityNfts[i],
                activeBountyId,
                account
            );
        }
    }

    /**
     * Handles the granting of XP, awarded to user staked NFTs
     * @param successXp The amount of XP to grant
     * @param activeBountyId The ID of the active bounty
     */
    function _handleXp(uint256 successXp, uint256 activeBountyId) internal {
        // Grant XP if any
        if (successXp > 0) {
            // Get user ActiveBounty component
            (, , , , , uint256[] memory entityInputs) = ActiveBountyComponent(
                _gameRegistry.getComponent(ACTIVE_BOUNTY_COMPONENT_ID)
            ).getValue(activeBountyId);
            address tokenContract;
            uint256 tokenId;
            for (uint256 i = 0; i < entityInputs.length; ++i) {
                (tokenContract, tokenId) = EntityLibrary.entityToToken(
                    entityInputs[i]
                );
                // Grant XP to NFT
                ILevelSystem(_getSystem(LEVEL_SYSTEM_ID)).grantXP(
                    tokenContract,
                    tokenId,
                    successXp
                );
            }
        }
    }

    /**
     * Converts a LootSetComponent to a ILootSystem.Loot array
     * @param lootSetId The LootSetComponent GUID
     */
    function _convertLootSet(
        uint256 lootSetId
    ) internal view returns (ILootSystem.Loot[] memory) {
        // Get the LootSet component values uisng the lootSetId
        (
            uint32[] memory lootType,
            address[] memory tokenContract,
            uint256[] memory lootId,
            uint256[] memory amount
        ) = LootSetComponent(_gameRegistry.getComponent(LOOT_SET_COMPONENT_ID))
                .getValue(lootSetId);
        // Convert them to an ILootSystem.Loot array
        ILootSystem.Loot[] memory loot = new ILootSystem.Loot[](
            lootType.length
        );
        for (uint256 i = 0; i < lootType.length; i++) {
            loot[i] = ILootSystem.Loot(
                ILootSystem.LootType(lootType[i]),
                tokenContract[i],
                lootId[i],
                amount[i]
            );
        }
        return loot;
    }

    function _convertBountyLootInput(
        BountyLootInput memory input
    ) internal pure returns (ILootSystem.Loot[] memory) {
        ILootSystem.Loot[] memory loot = new ILootSystem.Loot[](
            input.lootType.length
        );
        for (uint256 i = 0; i < input.lootType.length; i++) {
            loot[i] = ILootSystem.Loot(
                ILootSystem.LootType(input.lootType[i]),
                input.tokenContract[i],
                input.lootId[i],
                input.amount[i]
            );
        }
        return loot;
    }

    /**
     * Validates the SetBountyInputParam
     * @param definition The SetBountyInputParam to validate
     */
    function _validateSetBountyInput(
        SetBountyInputParam calldata definition
    ) internal view {
        // Run validation checks on Bounty definition
        // Check Bounty ID and Group ID is present
        if (definition.bountyId == 0 || definition.bountyGroupId == 0) {
            revert MissingInputs();
        }
        // Check Bounty bountyTimeLock, lowerBound, upperBound is present
        if (
            definition.bountyTimeLock == 0 ||
            definition.lowerBound == 0 ||
            definition.upperBound == 0
        ) {
            revert MissingInputs();
        }
        // Check Bounty input loot, base loot is present
        if (
            definition.inputLoot.lootEntity == 0 ||
            definition.outputLoot.lootEntity == 0
        ) {
            revert MissingInputs();
        }
        // Validate Bounty Input loot
        ILootSystem lootSystem = _lootSystem();
        lootSystem.validateLoots(_convertBountyLootInput(definition.inputLoot));
        // Validate Bounty Base loot
        lootSystem.validateLoots(
            _convertBountyLootInput(definition.outputLoot)
        );
    }

    /**
     * Verifies that the NFT is owned by the user and is a Pirate NFT
     * @param traitsProvider The TraitsProvider to use
     * @param entityId The entity ID of the NFT
     * @param account The account to check
     */
    function _checkPirateNft(
        ITraitsProvider traitsProvider,
        GenerationCheckComponentStruct memory generationCheckComponent,
        uint256 entityId,
        address account
    ) internal view {
        (address tokenContract, uint256 tokenId) = EntityLibrary.entityToToken(
            entityId
        );
        // Verify ownership
        if (account != IERC721(tokenContract).ownerOf(tokenId)) {
            revert NotNFTOwner();
        }

        uint256 gen = traitsProvider.getTraitUint256(
            tokenContract,
            tokenId,
            GENERATION_TRAIT_ID
        );
        if (generationCheckComponent.required) {
            if (gen != generationCheckComponent.generation) {
                revert InvalidGeneration();
            }
        }
    }

    /**
     * @dev Check and set NFTActiveBountyComponent
     * @param nftActiveBountyComponent NFTActiveBountyComponent
     * @param entityId entity ID of the NFT
     * @param activeBountyId activeBountyId
     * @param account account
     */
    function _checkAndSetNftActiveBountyComponent(
        NFTActiveBountyComponent nftActiveBountyComponent,
        uint256 entityId,
        uint256 activeBountyId,
        address account
    ) internal {
        NFTActiveBountyComponentStruct
            memory nftActiveBounty = nftActiveBountyComponent.getLayoutValue(
                entityId
            );
        // If the Pirate is on Bounty that belongs to caller wallet and its activeBountyId is not 0 then revert
        if (
            nftActiveBounty.walletUsed == account &&
            nftActiveBounty.activeBountyId != 0
        ) {
            revert BountyStillRunning();
        }
        // NFTActiveBountyComponent on this NFT: activeBountyId, walletUsed, timeLock, shouldCheckNft (for existing cases)
        nftActiveBountyComponent.setLayoutValue(
            entityId,
            NFTActiveBountyComponentStruct(activeBountyId, account, true)
        );
    }
}
