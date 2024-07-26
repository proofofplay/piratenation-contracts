// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {MANAGER_ROLE, GAME_NFT_CONTRACT_ROLE} from "../Constants.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {IHoldingSystem, ID} from "./IHoldingSystem.sol";
import {IHoldingConsumer} from "./IHoldingConsumer.sol";
import {IGameItems} from "../tokens/gameitems/IGameItems.sol";
import {ILootSystem} from "../loot/ILootSystem.sol";

/**
 * @title HoldingSystem
 *
 * Grants the user rewards based on how long they've held a given NFT
 */
contract HoldingSystem is GameRegistryConsumerUpgradeable, IHoldingSystem {
    // Milestone that maps time an NFT was held for to a loot table to grant loot from
    struct Milestone {
        // Amount of seconds the token needs to be held for to unlock milestone
        uint256 timeHeldSeconds;
        // Loot to grant once the milestone has been unlocked and claimed
        ILootSystem.Loot[] loots;
    }

    struct TokenContractInformation {
        // Which tokens have claimed which milestones
        mapping(uint256 => mapping(uint16 => bool)) claimed;
        // All of the milestones for this token contract
        Milestone[] milestones;
    }

    /// @notice  All of the possible token contracts with milestones associated with them
    mapping(address => TokenContractInformation) private _tokenContracts;

    struct IsClaimed {
        bool claimed;
        uint16 milestoneIndex;
    }

    /** EVENTS **/

    /// @notice Emitted when milestones have been set
    event MilestonesSet(address indexed tokenContract);

    /// @notice Emitted when a milestone has been claimed
    event MilestoneClaimed(
        address indexed owner,
        address indexed tokenContract,
        uint256 indexed tokenId,
        uint16 milestoneIndex
    );

    /// @notice Emitted when a milestone has been claimed in batch
    event BatchMilestoneClaimed(
        address indexed owner,
        address indexed tokenContract,
        uint256[] tokenIds,
        uint16[] milestoneIndices
    );

    /** ERRORS **/

    /// @notice tokenContract has not been allowlisted for gameplay
    error ContractNotAllowlisted(address tokenContract);

    /// @notice Milestone has already been claimed
    error MilestoneAlreadyClaimed(uint256 tokenId, uint16 milestoneIndex);

    /// @notice Milestone can only be claimed by token owner
    error NotOwner(uint256 tokenId, uint16 milestoneIndex);

    /// @notice Milestone index is invalid (greater than number of milestones)
    error InvalidMilestoneIndex(uint256 tokenId, uint16 milestoneIndex);

    /// @notice NFT has not been held long enough
    error MilestoneNotUnlocked(uint256 tokenId, uint16 milestoneIndex);

    /// @notice Array lengths are either zero or don't match
    error InvalidArrayLengths();

    /** SETUP **/

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /** PUBLIC **/

    /**
     * Sets the milestones for the given token contract
     *
     * @param tokenContract Token contract to set milestones for
     * @param milestones   New holding milestones for the contract
     */
    function setMilestones(
        address tokenContract,
        Milestone[] calldata milestones
    ) public onlyRole(MANAGER_ROLE) {
        if (_hasAccessRole(GAME_NFT_CONTRACT_ROLE, tokenContract) != true) {
            revert ContractNotAllowlisted(tokenContract);
        }

        TokenContractInformation storage tokenContractInfo = _tokenContracts[
            tokenContract
        ];

        // Reset array
        delete tokenContractInfo.milestones;

        ILootSystem lootSystem = _lootSystem();

        for (uint16 idx; idx < milestones.length; ++idx) {
            Milestone calldata milestone = milestones[idx];
            tokenContractInfo.milestones.push(milestones[idx]);
            lootSystem.validateLoots(milestone.loots);
        }

        // Emit event
        emit MilestonesSet(tokenContract);
    }

    /**
     * Number of claimed milestones for a token
     * @param tokenContract  Contract of the token that is being held
     * @param tokenId        Id of the token that is being held
     * @return uint256       Number of milestones claimed for that token
     */
    function milestonesClaimed(
        address tokenContract,
        uint256 tokenId
    ) external view returns (uint256) {
        TokenContractInformation storage info = _tokenContracts[tokenContract];

        uint256 claimed = 0;
        for (uint16 i; i < info.milestones.length; i++) {
            if (info.claimed[tokenId][i]) {
                claimed = claimed + 1;
            }
        }
        return claimed;
    }

    /**
     * Claims a token milestone for a given token
     *
     * @param tokenContract     Contract of the token that is being held
     * @param tokenId           Id of the token that is being held
     * @param milestoneIndex    Index of the milestone to claim for this token
     */
    function claimMilestone(
        address tokenContract,
        uint256 tokenId,
        uint16 milestoneIndex
    ) external whenNotPaused nonReentrant {
        address account = _getPlayerAccount(_msgSender());

        _claimMilestone(account, tokenContract, tokenId, milestoneIndex);

        emit MilestoneClaimed(account, tokenContract, tokenId, milestoneIndex);
    }

    /**
     * Claims multiple token milestones for a given token
     *
     * @param tokenContract     Contract of the token that is being held
     * @param tokenIds          Ids of the token that is being held
     * @param milestoneIndicies    Indicies of the milestone to claim for this token
     */
    function batchClaimMilestone(
        address tokenContract,
        uint256[] calldata tokenIds,
        uint16[] calldata milestoneIndicies
    ) external whenNotPaused nonReentrant {
        if (
            tokenIds.length == 0 || tokenIds.length != milestoneIndicies.length
        ) {
            revert InvalidArrayLengths();
        }

        address account = _getPlayerAccount(_msgSender());

        for (uint256 idx; idx < tokenIds.length; ++idx) {
            _claimMilestone(
                account,
                tokenContract,
                tokenIds[idx],
                milestoneIndicies[idx]
            );
        }

        emit BatchMilestoneClaimed(
            account,
            tokenContract,
            tokenIds,
            milestoneIndicies
        );
    }

    /**
     * MIGRATION-ONLY : Claims multiple token milestones for single tokenid
     * @dev No loot awarded
     * @param owners NFT owner addresses of token during claim
     * @param tokenContract NFT token address
     * @param tokenId single Token ID
     * @param milestoneIndicies Indicies of the milestone to claim
     */
    function batchMigrateMilestoneClaimed(
        address tokenContract,
        address[] calldata owners,
        uint256 tokenId,
        uint16[] calldata milestoneIndicies
    ) external onlyRole(MANAGER_ROLE) {
        if (owners.length != milestoneIndicies.length) {
            revert InvalidArrayLengths();
        }
        for (uint256 i; i < owners.length; i++) {
            // No loot award
            _migrateClaimMilestone(
                tokenContract,
                tokenId,
                milestoneIndicies[i]
            );
            emit MilestoneClaimed(
                owners[i],
                tokenContract,
                tokenId,
                milestoneIndicies[i]
            );
        }
    }

    /**
     * MIGRATION-ONLY : Claims multiple token milestones for multiple tokenids
     * @dev No loot awarded
     * @param owner NFT owner address of token during claim
     * @param tokenContract NFT token address
     * @param tokenIds Token IDs
     * @param milestoneIndicies Indicies of the milestone to claim for each token id
     */
    function batchMigrateBatchMilestoneClaimed(
        address tokenContract,
        address owner,
        uint256[] calldata tokenIds,
        uint16[] calldata milestoneIndicies
    ) external onlyRole(MANAGER_ROLE) {
        if (tokenIds.length != milestoneIndicies.length) {
            revert InvalidArrayLengths();
        }
        for (uint256 i; i < tokenIds.length; i++) {
            // No loot award
            _migrateClaimMilestone(
                tokenContract,
                tokenIds[i],
                milestoneIndicies[i]
            );
        }

        emit BatchMilestoneClaimed(
            owner,
            tokenContract,
            tokenIds,
            milestoneIndicies
        );
    }

    /**
     * Get all milestone info for a given token and account
     *
     * @param account       Account to get info for
     * @param tokenContract Contract to get milestones for
     * @param tokenId       Token id to get milestones for
     *
     * @return unlocked Whether or not the milestone is unlocked
     * @return claimed Whether or not the milestone is unlocked
     */
    function getTokenStatus(
        address account,
        address tokenContract,
        uint256 tokenId
    )
        external
        view
        returns (
            bool[] memory unlocked,
            bool[] memory claimed,
            uint256[] memory timeLeftSeconds
        )
    {
        TokenContractInformation storage contractInfo = _tokenContracts[
            tokenContract
        ];
        Milestone[] storage milestones = contractInfo.milestones;
        unlocked = new bool[](milestones.length);
        claimed = new bool[](milestones.length);
        timeLeftSeconds = new uint256[](milestones.length);
        uint32 timeHeld = _timeHeld(account, tokenContract, tokenId);

        for (uint16 idx; idx < milestones.length; ++idx) {
            Milestone storage milestone = milestones[idx];
            unlocked[idx] = _isMilestoneUnlocked(
                milestones[idx],
                account,
                tokenContract,
                tokenId
            );

            if (milestone.timeHeldSeconds > timeHeld) {
                timeLeftSeconds[idx] = milestone.timeHeldSeconds - timeHeld;
            } else {
                timeLeftSeconds[idx] = 0;
            }

            claimed[idx] = contractInfo.claimed[tokenId][idx];
        }
    }

    /**
     * Return milestones for a given token contract
     *
     * @param tokenContract Contract to get milestones for
     *
     * @return All milestones for the given token contract
     */
    function getTokenContractMilestones(
        address tokenContract
    ) external view returns (Milestone[] memory) {
        return _tokenContracts[tokenContract].milestones;
    }

    /** INTERNAL */

    /**
     * Claims a token milestone for a given token
     *
     * @param account           Sender account
     * @param tokenContract     Contract of the token that is being held
     * @param tokenId           Id of the token that is being held
     * @param milestoneIndex    Index of the milestone to claim for this token
     */
    function _claimMilestone(
        address account,
        address tokenContract,
        uint256 tokenId,
        uint16 milestoneIndex
    ) internal {
        if (account != IERC721(tokenContract).ownerOf(tokenId)) {
            revert NotOwner(tokenId, milestoneIndex);
        }

        TokenContractInformation storage tokenContractInfo = _tokenContracts[
            tokenContract
        ];

        if (milestoneIndex >= tokenContractInfo.milestones.length) {
            revert InvalidMilestoneIndex(tokenId, milestoneIndex);
        }

        if (tokenContractInfo.claimed[tokenId][milestoneIndex] == true) {
            revert MilestoneAlreadyClaimed(tokenId, milestoneIndex);
        }

        Milestone storage milestone = tokenContractInfo.milestones[
            milestoneIndex
        ];

        if (
            _isMilestoneUnlocked(milestone, account, tokenContract, tokenId) !=
            true
        ) {
            revert MilestoneNotUnlocked(tokenId, milestoneIndex);
        }

        // Mark as claimed
        tokenContractInfo.claimed[tokenId][milestoneIndex] = true;

        // Grant loot
        _lootSystem().grantLoot(account, milestone.loots);
    }

    function _timeHeld(
        address,
        address tokenContract,
        uint256 tokenId
    ) internal view returns (uint32) {
        uint32 lastTransfer = IHoldingConsumer(tokenContract).getLastTransfer(
            tokenId
        );
        return uint32(block.timestamp) - lastTransfer;
    }

    function _isMilestoneUnlocked(
        Milestone storage milestone,
        address account,
        address tokenContract,
        uint256 tokenId
    ) internal view returns (bool) {
        return
            _timeHeld(account, tokenContract, tokenId) >=
            milestone.timeHeldSeconds;
    }

    /**
     * MIGRATION-ONLY: Updates storage with new claimed data but does not disperse loot
     */
    function _migrateClaimMilestone(
        address tokenContract,
        uint256 tokenId,
        uint16 milestoneIndex
    ) internal {
        // update: no check of ownership during migration for HoldingSystem
        // if (account != IERC721(tokenContract).ownerOf(tokenId)) {
        //     revert NotOwner(tokenId, milestoneIndex);
        // }

        TokenContractInformation storage tokenContractInfo = _tokenContracts[
            tokenContract
        ];

        if (milestoneIndex >= tokenContractInfo.milestones.length) {
            revert InvalidMilestoneIndex(tokenId, milestoneIndex);
        }

        if (tokenContractInfo.claimed[tokenId][milestoneIndex] == true) {
            revert MilestoneAlreadyClaimed(tokenId, milestoneIndex);
        }

        // update : no milestoneUnlocked check during migration
        // Milestone storage milestone = tokenContractInfo.milestones[milestoneIndex];
        // if (_isMilestoneUnlocked(milestone, account, tokenContract, tokenId) != true) {
        //     revert MilestoneNotUnlocked(tokenId, milestoneIndex);
        // }

        // Mark as claimed
        tokenContractInfo.claimed[tokenId][milestoneIndex] = true;

        // Grant loot : update : no re-granting of loot during migration for HoldingSystem
        // _lootSystem().grantLoot(account, milestone.loots);
    }

    function getAllClaimedMilestones(
        address tokenContract,
        uint256 tokenId
    ) external view returns (IsClaimed[] memory) {
        TokenContractInformation storage info = _tokenContracts[tokenContract];
        IsClaimed[] memory claimedMilestones = new IsClaimed[](
            info.milestones.length
        );
        for (uint16 i; i < info.milestones.length; i++) {
            claimedMilestones[i].claimed = info.claimed[tokenId][i];
            claimedMilestones[i].milestoneIndex = i;
        }
        return claimedMilestones;
    }
}
