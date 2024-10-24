// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../libraries/RandomLibrary.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";

import {GAME_LOGIC_CONTRACT_ROLE, GAME_NFT_CONTRACT_ROLE, GENERATION_TRAIT_ID, LEVEL_TRAIT_ID, IS_PIRATE_TRAIT_ID} from "../Constants.sol";

import {ILevelSystem, ID as LEVEL_SYSTEM_ID} from "../level/ILevelSystem.sol";
import {ITransformRunnerSystem, TransformParams} from "./ITransformRunnerSystem.sol";
import {BountyTransformConfigComponent, Layout as BountyTransformConfigComponentLayout, ID as BOUNTY_TRANSFORM_CONFIG_COMPONENT_ID} from "../generated/components/BountyTransformConfigComponent.sol";
import {LootEntityArrayComponent, Layout as LootEntityArrayComponentLayout} from "../generated/components/LootEntityArrayComponent.sol";
import {BaseTransformRunnerSystem, TransformInputComponentLayout, TransformInstanceComponentLayout} from "./BaseTransformRunnerSystem.sol";
import {EntityListComponent, Layout as EntityListComponentLayout, ID as ENTITY_LIST_COMPONENT_ID} from "../generated/components/EntityListComponent.sol";
import {GenerationCheckComponent, Layout as GenerationCheckComponentLayout, ID as GENERATION_CHECK_COMPONENT_ID} from "../generated/components/GenerationCheckComponent.sol";
import {TransformBountyTrackerComponent, Layout as TransformBountyTrackerComponentLayout, ID as TRANSFORM_BOUNTY_TRACKER_ID} from "../generated/components/TransformBountyTrackerComponent.sol";
import {ParentComponent, ID as PARENT_COMPONENT_ID} from "../generated/components/ParentComponent.sol";
import {GenerationComponent, ID as GENERATION_COMPONENT_ID} from "../generated/components/GenerationComponent.sol";
import {GameNFTV2Upgradeable} from "../tokens/gamenft/GameNFTV2Upgradeable.sol";
import {CounterComponent, ID as COUNTER_COMPONENT_ID} from "../generated/components/CounterComponent.sol";
import {IsPirateComponent, Layout as IsPirateComponentLayout, ID as IS_PIRATE_COMPONENT_ID} from "../generated/components/IsPirateComponent.sol";

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

    /// @notice Error Bounty still running
    error BountyStillRunning();

    /// @notice Error when invalid generation
    error InvalidGeneration();

    /// @notice Error when invalid amount of pirates staked
    error InvalidAmountOfPiratesStaked();

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
        returns (bool needsVrf, bool skipTransformInstance)
    {
        uint256 transformEntity = params.transformEntity;
        address account = transformInstance.account;

        BountyTransformConfigComponentLayout
            memory runnerConfig = _getBountyTransformRunnerConfig(
                transformEntity
            );

        uint256[] memory entities = abi.decode(params.data, (uint256[]));

        if (entities.length == 0) {
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
            revert InvalidAmountOfPiratesStaked();
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
        // Set parent bounty group count to 1 to indicate this type of bounty is in progress
        uint256 bountyParentTransformId = EntityLibrary.accountSubEntity(
            account,
            parentEntity
        );
        CounterComponent(_gameRegistry.getComponent(COUNTER_COMPONENT_ID))
            .setValue(bountyParentTransformId, 1);

        // Store bounty nfts on the transform instance
        EntityListComponent(
            _gameRegistry.getComponent(ENTITY_LIST_COMPONENT_ID)
        ).setValue(transformInstanceEntity, entities);

        return (needsVrf, skipTransformInstance);
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

        uint256 bountyParentTransformId = EntityLibrary.accountSubEntity(
            account,
            parentEntity
        );
        CounterComponent counterComponent = CounterComponent(
            _gameRegistry.getComponent(COUNTER_COMPONENT_ID)
        );
        // Remove parent bounty group count to indicate this type of bounty is no longer in progress
        if (counterComponent.has(bountyParentTransformId)) {
            counterComponent.remove(bountyParentTransformId);
        }

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
        // Check if user has a pending bounty for this Bounty type
        CounterComponent counterComponent = CounterComponent(
            _gameRegistry.getComponent(COUNTER_COMPONENT_ID)
        );
        uint256 bountyParentTransformId = EntityLibrary.accountSubEntity(
            account,
            parentId
        );
        if (counterComponent.has(bountyParentTransformId)) {
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
        TransformBountyTrackerComponent bountyTrackerComponent = TransformBountyTrackerComponent(
                _gameRegistry.getComponent(TRANSFORM_BOUNTY_TRACKER_ID)
            );
        for (uint256 i = 0; i < entityInputs.length; ++i) {
            (tokenContract, tokenId) = EntityLibrary.entityToToken(
                entityInputs[i]
            );
            TransformBountyTrackerComponentLayout
                memory activeBounty = bountyTrackerComponent.getLayoutValue(
                    entityInputs[i]
                );
            // Handle crosschain nfts
            bool nftExists = GameNFTV2Upgradeable(tokenContract).exists(
                tokenId
            );
            if (!nftExists) {
                bountyTrackerComponent.remove(entityInputs[i]);
                failedBounty = true;
                continue;
            }
            address nftOwner = GameNFTV2Upgradeable(tokenContract).ownerOf(
                tokenId
            );

            // If activeBountyId matches and caller is owner then clear the component
            if (
                transformInstanceEntity ==
                activeBounty.transformInstanceEntity &&
                account == nftOwner
            ) {
                bountyTrackerComponent.remove(entityInputs[i]);
            } else {
                // Otherwise mark bounty as failed
                failedBounty = true;
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
        TransformBountyTrackerComponent bountyTrackerComponent = TransformBountyTrackerComponent(
                _gameRegistry.getComponent(TRANSFORM_BOUNTY_TRACKER_ID)
            );
        GenerationCheckComponentLayout
            memory generationCheckComponent = GenerationCheckComponent(
                _gameRegistry.getComponent(GENERATION_CHECK_COMPONENT_ID)
            ).getLayoutValue(parentEntity);
        GenerationComponent generationComponent = GenerationComponent(
            _gameRegistry.getComponent(GENERATION_COMPONENT_ID)
        );
        IsPirateComponent isPirateComponent = IsPirateComponent(
            _gameRegistry.getComponent(IS_PIRATE_COMPONENT_ID)
        );
        for (uint256 i = 0; i < entityNfts.length; ++i) {
            // Check Pirate NFT
            _checkPirateNft(
                transformInstanceEntity,
                generationComponent,
                generationCheckComponent,
                bountyTrackerComponent,
                isPirateComponent,
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
     * @param entityId The entity ID of the NFT
     * @param account The account to check
     */
    function _checkPirateNft(
        uint256 transformInstanceEntity,
        GenerationComponent generationComponent,
        GenerationCheckComponentLayout memory generationCheckComponent,
        TransformBountyTrackerComponent transformBountyTrackerComponent,
        IsPirateComponent isPirateComponent,
        uint256 entityId,
        address account
    ) internal {
        // Check if NFT is Pirate
        if (isPirateComponent.getValue(entityId) == false) {
            revert NotPirateNFT();
        }
        (address tokenContract, uint256 tokenId) = EntityLibrary.entityToToken(
            entityId
        );
        // Verify ownership
        if (account != IERC721(tokenContract).ownerOf(tokenId)) {
            revert NotNFTOwner();
        }
        uint256 gen = generationComponent.getValue(entityId);
        if (generationCheckComponent.required) {
            if (gen != generationCheckComponent.generation) {
                revert InvalidGeneration();
            }
        }

        // See if pirate is already on a bounty
        TransformBountyTrackerComponentLayout
            memory activeBounty = transformBountyTrackerComponent
                .getLayoutValue(entityId);

        // If the Pirate is on Bounty that belongs to caller wallet and its activeBountyId is not 0 then revert
        if (
            activeBounty.wallet == account &&
            activeBounty.transformInstanceEntity != 0
        ) {
            revert BountyStillRunning();
        }

        transformBountyTrackerComponent.setLayoutValue(
            entityId,
            TransformBountyTrackerComponentLayout(
                transformInstanceEntity,
                account
            )
        );
    }
}
