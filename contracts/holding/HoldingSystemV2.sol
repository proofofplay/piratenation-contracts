// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {EntityLibrary} from "../core/EntityLibrary.sol";
import {LootArrayComponentLibrary} from "../loot/LootArrayComponentLibrary.sol";

import {IHoldingConsumer} from "./IHoldingConsumer.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {ILootSystemV2, ID as LOOT_SYSTEM_ID} from "../loot/ILootSystemV2.sol";
import {LootEntityArrayComponent, Layout as LootEntityArrayComponentLayout, ID as LOOT_ENTITY_ARRAY_COMPONENT_ID} from "../generated/components/LootEntityArrayComponent.sol";
import {MilestonesClaimedComponent, Layout as MilestonesClaimedComponentLayout, ID as MILESTONES_CLAIMED_COMPONENT_ID} from "../generated/components/MilestonesClaimedComponent.sol";
import {MilestoneRulesComponent, Layout as MilestoneRulesComponentLayout, ID as MILESTONE_RULES_COMPONENT_ID} from "../generated/components/MilestoneRulesComponent.sol";
import {ID as PIRATE_NFT_ID} from "../tokens/PirateNFTL2.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.holdingsystem.v2"));

/**
 * @title HoldingSystemV2
 *
 * Grants the user rewards based on how long they've held a given NFT
 */
contract HoldingSystemV2 is GameRegistryConsumerUpgradeable {
    /** ERRORS **/

    /// @notice Invalid milestone index
    error InvalidMilestoneIndex(uint256 nftEntity, uint256 milestoneIndex);

    /// @notice Milestone already claimed
    error MilestoneAlreadyClaimed(uint256 nftEntity, uint256 milestoneIndex);

    /// @notice Invalid contract
    error InvalidContract();

    /// @notice Array lengths are either zero or don't match
    error InvalidArrayLengths();

    /// @notice Milestone can only be claimed by token owner
    error NotOwner(uint256 tokenId, uint256 milestoneIndex);

    /// @notice NFT has not been held long enough
    error MilestoneNotUnlocked(uint256 nftEntity, uint256 milestoneIndex);

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
     * Claims a token milestone for a given token
     *
     * @param nftEntity         Entity of the NFT that is being held
     * @param milestoneIndex    Index of the milestone to claim for this token
     */
    function claimMilestone(
        uint256 nftEntity,
        uint16 milestoneIndex
    ) external whenNotPaused nonReentrant {
        address account = _getPlayerAccount(_msgSender());
        _claimMilestone(account, nftEntity, milestoneIndex);
    }

    /**
     * Claims multiple token milestones for a given token
     *
     * @param nftEntities        Entities of the NFTs that are being held
     * @param milestoneIndicies    Indicies of the milestone to claim for this token
     */
    function batchClaimMilestone(
        uint256[] calldata nftEntities,
        uint256[] calldata milestoneIndicies
    ) external whenNotPaused nonReentrant {
        if (
            nftEntities.length == 0 ||
            nftEntities.length != milestoneIndicies.length
        ) {
            revert InvalidArrayLengths();
        }

        address account = _getPlayerAccount(_msgSender());

        for (uint256 idx; idx < nftEntities.length; ++idx) {
            _claimMilestone(account, nftEntities[idx], milestoneIndicies[idx]);
        }
    }

    /** INTERNAL */

    /**
     * Claims a token milestone for a given token
     *
     * @param account           Sender account
     * @param nftEntity         Entity of the NFT that is being held
     * @param milestoneIndex    Index of the milestone to claim for this token
     */
    function _claimMilestone(
        address account,
        uint256 nftEntity,
        uint256 milestoneIndex
    ) internal {
        (address tokenContract, uint256 tokenId) = EntityLibrary.entityToToken(
            nftEntity
        );
        if (tokenContract != _getSystem(PIRATE_NFT_ID)) {
            revert InvalidContract();
        }
        if (account != IERC721(tokenContract).ownerOf(tokenId)) {
            revert NotOwner(tokenId, milestoneIndex);
        }
        // Get the milestone rules
        MilestoneRulesComponentLayout
            memory milestoneRulesComponentLayout = MilestoneRulesComponent(
                _gameRegistry.getComponent(MILESTONE_RULES_COMPONENT_ID)
            ).getLayoutValue(ID);
        // Check valid milestone index
        if (
            milestoneIndex >=
            milestoneRulesComponentLayout.milestoneRewards.length
        ) {
            revert InvalidMilestoneIndex(nftEntity, milestoneIndex);
        }
        // Get the milestones claimed for this nft
        MilestonesClaimedComponent milestonesClaimedComponent = MilestonesClaimedComponent(
                _gameRegistry.getComponent(MILESTONES_CLAIMED_COMPONENT_ID)
            );
        MilestonesClaimedComponentLayout
            memory milestonesClaimedComponentLayout = milestonesClaimedComponent
                .getLayoutValue(nftEntity);
        // Check if milestone already claimed
        for (
            uint16 i = 0;
            i < milestonesClaimedComponentLayout.milestoneIndexesClaimed.length;
            i++
        ) {
            if (
                milestonesClaimedComponentLayout.milestoneIndexesClaimed[i] ==
                milestoneIndex
            ) {
                revert MilestoneAlreadyClaimed(nftEntity, milestoneIndex);
            }
        }
        // Check if milestone is unlocked
        uint256 requiredTime = milestoneRulesComponentLayout.milestoneTimes[
            milestoneIndex
        ];
        if (_timeHeld(tokenContract, tokenId) < requiredTime) {
            revert MilestoneNotUnlocked(nftEntity, milestoneIndex);
        }
        // Update the milestones claimed
        MilestonesClaimedComponentLayout
            memory newMilestonesClaimedComponentLayout = MilestonesClaimedComponentLayout({
                milestoneIndexesClaimed: new uint256[](1)
            });
        newMilestonesClaimedComponentLayout.milestoneIndexesClaimed[
                0
            ] = milestoneIndex;
        milestonesClaimedComponent.append(
            nftEntity,
            newMilestonesClaimedComponentLayout
        );
        // Get the reward for the milestone
        uint256 lootEntityId = milestoneRulesComponentLayout.milestoneRewards[
            milestoneIndex
        ];
        ILootSystemV2.Loot[] memory loots = LootArrayComponentLibrary
            .convertLootEntityArrayToLoot(
                _gameRegistry.getComponent(LOOT_ENTITY_ARRAY_COMPONENT_ID),
                lootEntityId
            );
        // Grant the loot
        ILootSystemV2(_gameRegistry.getSystem(LOOT_SYSTEM_ID)).grantLoot(
            account,
            loots
        );
    }

    function _timeHeld(
        address tokenContract,
        uint256 tokenId
    ) internal view returns (uint32) {
        uint32 lastTransfer = IHoldingConsumer(tokenContract).getLastTransfer(
            tokenId
        );
        return uint32(block.timestamp) - lastTransfer;
    }
}
