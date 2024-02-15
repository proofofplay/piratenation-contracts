// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../libraries/RandomLibrary.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {PirateLibrary} from "../libraries/PirateLibrary.sol";

import {GAME_LOGIC_CONTRACT_ROLE, GAME_NFT_CONTRACT_ROLE, GENERATION_TRAIT_ID, LEVEL_TRAIT_ID, IS_PIRATE_TRAIT_ID} from "../Constants.sol";

import {ILevelSystem, ID as LEVEL_SYSTEM_ID} from "../level/ILevelSystem.sol";
import {ITransformRunnerSystem, TransformParams} from "./ITransformRunnerSystem.sol";
import {BountyTransformConfigComponent, Layout as BountyTransformConfigComponentLayout, ID as BOUNTY_TRANSFORM_CONFIG_COMPONENT_ID} from "../generated/components/BountyTransformConfigComponent.sol";
import {LootEntityArrayComponent, Layout as LootEntityArrayComponentLayout} from "../generated/components/LootEntityArrayComponent.sol";
import {BaseTransformRunnerSystem, TransformInputComponentLayout, TransformInstanceComponentLayout} from "./BaseTransformRunnerSystem.sol";
import {EntityListComponent, Layout as EntityListComponentLayout, ID as ENTITY_LIST_COMPONENT_ID} from "../generated/components/EntityListComponent.sol";
import {ITraitsProvider} from "../interfaces/ITraitsProvider.sol";
import {GenerationCheckComponent, Layout as GenerationCheckComponentLayout, ID as GENERATION_CHECK_COMPONENT_ID} from "../generated/components/GenerationCheckComponent.sol";
import {NFTActiveBountyComponent, Layout as NFTActiveBountyComponentLayout, ID as NFT_ACTIVE_BOUNTY_COMPONENT_ID} from "../generated/components/NFTActiveBountyComponent.sol";
import {ParentComponent, ID as PARENT_COMPONENT_ID} from "../generated/components/ParentComponent.sol";
import {ICooldownSystem, ID as COOLDOWN_SYSTEM_ID} from "../cooldown/ICooldownSystem.sol";
import {CountingSystem, ID as COUNTING_SYSTEM_ID} from "../counting/CountingSystem.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.bountytransformrunnersystem")
);

contract BountyTransformRunnerSystem is BaseTransformRunnerSystem {
    /** ERRORS */

    /// @notice Error when invalid inputs
    error InvalidInputs();

    /// @notice Error when caller is not NFT owner
    error NotNFTOwner();

    /// @notice Error when NFT not Pirate
    error NotPirateNFT();

    /// @notice Error when Bounty not in progress
    error BountyNotInProgress();

    /// @notice Error Bounty still running
    error BountyStillRunning();

    /// @notice Error when invalid generation
    error InvalidGeneration();

    /** PUBLIC */

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function startTransform(
        TransformInstanceComponentLayout memory transformInstance,
        uint256 transformInstanceEntity,
        TransformParams calldata params
    )
        external
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (bool needsVrf)
    {
        uint256 transformEntity = params.transformEntity;
        address account = transformInstance.account;

        BountyTransformConfigComponentLayout
            memory runnerConfig = _getBountyTransformRunnerConfig(
                transformEntity
            );

        uint256[] memory entities = abi.decode(params.data, (uint256[]));

        if (transformEntity == 0 || entities.length == 0) {
            revert InvalidInputs();
        }

        // Fail if trying to run more than 1 at a time
        if (params.count > 1) {
            revert InvalidInputs();
        }

        // Check that amount of NFTs is within bounds
        if (
            entities.length < runnerConfig.lowerBound ||
            entities.length > runnerConfig.upperBound
        ) {
            revert InvalidInputs();
        }

        // Get parent
        uint256 parentEntity = ParentComponent(
            _gameRegistry.getComponent(PARENT_COMPONENT_ID)
        ).getValue(transformEntity);

        // Verify there's a parent entity
        if (parentEntity == 0) {
            revert InvalidInputs();
        }

        // Verift ownership, verify NFT IS_PIRATE, check and set NftActiveBountyComponent
        _verifyNftInputs(
            account,
            entities,
            transformInstanceEntity,
            parentEntity
        );

        // Add a cooldown on this User Wallet + Bounty Component Group ID to ensure user can only run 1 type of this Bounty at a time
        if (
            ICooldownSystem(_getSystem(COOLDOWN_SYSTEM_ID))
                .updateAndCheckCooldown(
                    EntityLibrary.addressToEntity(account),
                    parentEntity,
                    runnerConfig.timeLock
                )
        ) {
            revert BountyStillRunning();
        }

        // Increment the pending count for this bounty group (parentEntity) by 1
        CountingSystem(_gameRegistry.getSystem(COUNTING_SYSTEM_ID))
            .incrementCount(
                parentEntity,
                EntityLibrary.addressToEntity(account),
                1
            );

        // Store bounty nfts on the transform instance
        EntityListComponent(
            _gameRegistry.getComponent(ENTITY_LIST_COMPONENT_ID)
        ).setValue(transformInstanceEntity, entities);

        return false;
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function completeTransform(
        TransformInstanceComponentLayout memory transformInstance,
        uint256 transformInstanceEntity,
        uint256 randomWord
    )
        external
        override
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (uint16 numSuccess, uint256 nextRandomWord)
    {
        numSuccess = 0;

        address account = transformInstance.account;
        uint256 parentEntity = ParentComponent(
            _gameRegistry.getComponent(PARENT_COMPONENT_ID)
        ).getValue(transformInstance.transformEntity);

        // Get runner config
        BountyTransformConfigComponentLayout
            memory runnerConfig = _getBountyTransformRunnerConfig(
                transformInstance.transformEntity
            );

        // Check that user still owns the NFTs that were staked for the bounty
        bool failedBounty = _checkStakedNfts(account, transformInstanceEntity);
        if (failedBounty == false) {
            _handleXp(runnerConfig.successXp, transformInstanceEntity);
            numSuccess = transformInstance.count;
        }

        // Set pending bounty count to 0 for the parent bounty group
        CountingSystem(_gameRegistry.getSystem(COUNTING_SYSTEM_ID)).setCount(
            parentEntity,
            EntityLibrary.addressToEntity(account),
            0
        );

        return (numSuccess, randomWord);
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function isTransformAvailable(
        address account,
        TransformParams calldata params
    ) external view override returns (bool) {
        // Get parent / group of this bounty
        uint256 parentEntity = ParentComponent(
            _gameRegistry.getComponent(PARENT_COMPONENT_ID)
        ).getValue(params.transformEntity);

        // If user has a pending bounty for this Bounty type, return false
        if (_hasPendingBounty(account, parentEntity)) {
            return false;
        }

        return true;
    }

    /**
     * @inheritdoc ITransformRunnerSystem
     */
    function isTransformCompleteable(
        TransformInstanceComponentLayout memory transformInstance
    ) external view override returns (bool) {
        return _isCompleteable(transformInstance);
    }

    /** INTERNAL */

    /**
     * @dev Return boolean if a user has a pending bounty for a given Bounty type
     * @param account Account to check
     * @param parentId Group Id of the Bounty to check
     * @return Whether or not the user has a pending bounty for the given Bounty type
     */
    function _hasPendingBounty(
        address account,
        uint256 parentId
    ) internal view returns (bool) {
        // The CountingSystem entity is Bounty ID and key is User Wallet
        if (
            CountingSystem(_gameRegistry.getSystem(COUNTING_SYSTEM_ID))
                .getCount(parentId, EntityLibrary.addressToEntity(account)) > 0
        ) {
            return true;
        }
        return false;
    }

    function _getBountyTransformRunnerConfig(
        uint256 transformEntity
    ) internal view returns (BountyTransformConfigComponentLayout memory) {
        BountyTransformConfigComponent configComponent = BountyTransformConfigComponent(
                _gameRegistry.getComponent(BOUNTY_TRANSFORM_CONFIG_COMPONENT_ID)
            );
        BountyTransformConfigComponentLayout
            memory runnerConfig = configComponent.getLayoutValue(
                transformEntity
            );
        return runnerConfig;
    }

    /**
     * @dev Check that user still owns the NFTs that were staked for the bounty
     * @param account Account to check
     * @param transformInstanceEntity Entity of the transform instance
     */
    function _checkStakedNfts(
        address account,
        uint256 transformInstanceEntity
    ) internal returns (bool) {
        bool failedBounty;

        uint256[] memory entityInputs = EntityListComponent(
            _gameRegistry.getComponent(ENTITY_LIST_COMPONENT_ID)
        ).getValue(transformInstanceEntity);

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
            NFTActiveBountyComponentLayout
                memory nftActiveBounty = nftActiveBountyComponent
                    .getLayoutValue(entityInputs[i]);
            // Get NFT current owner address
            address nftOwner = IERC721(tokenContract).ownerOf(tokenId);
            if (nftActiveBounty.shouldCheckNft == true) {
                // If activeBountyId matches and caller is owner then clear the component
                if (
                    transformInstanceEntity == nftActiveBounty.activeBountyId &&
                    account == nftOwner
                ) {
                    nftActiveBountyComponent.setLayoutValue(
                        entityInputs[i],
                        NFTActiveBountyComponentLayout(0, address(0), true)
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
     * @param transformInstance Instance of the transform entity
     */
    function _isCompleteable(
        TransformInstanceComponentLayout memory transformInstance
    ) internal view returns (bool) {
        BountyTransformConfigComponentLayout
            memory runnerConfig = _getBountyTransformRunnerConfig(
                transformInstance.transformEntity
            );

        // Check if Bounty valid to end
        if (
            block.timestamp <
            transformInstance.startTime + runnerConfig.timeLock
        ) {
            return false;
        }

        return true;
    }

    /**
     * Verify valid NFT inputs for staking : User is owner, token is IS_PIRATE, token is not on cooldown, apply cooldown on token
     * @param account User account
     * @param entityNfts Array of entity NFTs to verify
     * @param transformInstanceEntity ID of the active bounty
     * @param parentEntity Group ID of the bounty
     */
    function _verifyNftInputs(
        address account,
        uint256[] memory entityNfts,
        uint256 transformInstanceEntity,
        uint256 parentEntity
    ) internal {
        NFTActiveBountyComponent nftActiveBountyComponent = NFTActiveBountyComponent(
                _gameRegistry.getComponent(NFT_ACTIVE_BOUNTY_COMPONENT_ID)
            );
        GenerationCheckComponentLayout
            memory generationCheckComponent = GenerationCheckComponent(
                _gameRegistry.getComponent(GENERATION_CHECK_COMPONENT_ID)
            ).getLayoutValue(parentEntity);

        ITraitsProvider traitsProvider = _traitsProvider();
        for (uint256 i = 0; i < entityNfts.length; ++i) {
            // Check Pirate NFT
            _checkPirateNft(
                transformInstanceEntity,
                traitsProvider,
                generationCheckComponent,
                nftActiveBountyComponent,
                entityNfts[i],
                account
            );
        }
    }

    /**
     * Handles the granting of XP, awarded to user staked NFTs
     * @param successXp The amount of XP to grant
     * @param transformInstance Id of the transform instance
     */
    function _handleXp(uint256 successXp, uint256 transformInstance) internal {
        // Grant XP if any
        if (successXp > 0) {
            // Get user ActiveBounty component
            uint256[] memory entityInputs = EntityListComponent(
                _gameRegistry.getComponent(ENTITY_LIST_COMPONENT_ID)
            ).getValue(transformInstance);
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
     * Verifies that the NFT is owned by the user and is a Pirate NFT
     * @param traitsProvider The TraitsProvider to use
     * @param entityId The entity ID of the NFT
     * @param account The account to check
     */
    function _checkPirateNft(
        uint256 transformInstanceEntity,
        ITraitsProvider traitsProvider,
        GenerationCheckComponentLayout memory generationCheckComponent,
        NFTActiveBountyComponent nftActiveBountyComponent,
        uint256 entityId,
        address account
    ) internal {
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

        // See if pirate is already on a bounty
        NFTActiveBountyComponentLayout
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

        nftActiveBountyComponent.setLayoutValue(
            entityId,
            NFTActiveBountyComponentLayout(
                transformInstanceEntity,
                account,
                true
            )
        );
    }
}
