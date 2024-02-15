// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import {IGameItems} from "../tokens/gameitems/IGameItems.sol";
import {IGameCurrency} from "../tokens/IGameCurrency.sol";
import {ILootSystem} from "../loot/ILootSystem.sol";
import {ILootSystemV2} from "../loot/ILootSystemV2.sol";
import {GameRegistryLibrary} from "../libraries/GameRegistryLibrary.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";

import {LootArrayComponent, Layout as LootArrayComponentStruct} from "../generated/components/LootArrayComponent.sol";
import {LootEntityArrayComponent, Layout as LootEntityArrayComponentStruct} from "../generated/components/LootEntityArrayComponent.sol";
import {TransformInputComponent, Layout as TransformInputComponentStruct} from "../generated/components/TransformInputComponent.sol";

/**
 * Common helper functions for dealing with LootArrayComponents
 */
library LootArrayComponentLibrary {
    error InvalidInputs();

    /**
     * @dev Handle burning LootArrayComponent inputs
     * @param lootArrayComponent Address for LootArrayComponent
     * @param account Account to burn the input fees from
     * @param entity Entity of the LootArrayComponent that holds the input fees
     */
    function burnLootArray(
        address lootArrayComponent,
        address account,
        uint256 entity
    ) internal {
        // Get the input loots
        LootArrayComponent component = LootArrayComponent(lootArrayComponent);
        LootArrayComponentStruct memory lootArrayStruct = component
            .getLayoutValue(entity);

        // Revert if no entry loots found
        if (lootArrayStruct.lootType.length == 0) {
            revert InvalidInputs();
        }
        for (uint256 i = 0; i < lootArrayStruct.lootType.length; ++i) {
            _burnInput(
                account,
                lootArrayStruct.tokenContract[i],
                lootArrayStruct.lootId[i],
                lootArrayStruct.amount[i],
                lootArrayStruct.lootType[i]
            );
        }
    }

    /**
     * @dev Handle burning TransformInputComponent inputs
     * @param transformInputComponent Address for TransformInputComponent
     * @param account Account to burn the input fees from
     * @param entity ID of the LootSetComponent that holds the input fees
     */
    function burnTransformInput(
        address transformInputComponent,
        address account,
        uint256 entity
    ) internal {
        TransformInputComponentStruct
            memory transformInput = TransformInputComponent(
                transformInputComponent
            ).getLayoutValue(entity);

        // Revert if no entry loots found
        if (transformInput.inputType.length == 0) {
            revert InvalidInputs();
        }

        uint256 tokenId;
        address tokenContract;
        for (uint256 idx = 0; idx < transformInput.inputType.length; ++idx) {
            (tokenContract, tokenId) = EntityLibrary.entityToToken(
                transformInput.inputEntity[idx]
            );

            _burnInput(
                account,
                tokenContract,
                tokenId,
                transformInput.amount[idx],
                transformInput.inputType[idx]
            );
        }
    }

    /**
     * @dev Converts an array of ILootSystem.Loot to arrays
     */
    function convertLootToArrays(
        ILootSystem.Loot[] calldata items
    )
        internal
        pure
        returns (
            uint32[] memory lootType,
            address[] memory tokenContract,
            uint256[] memory lootId,
            uint256[] memory amount
        )
    {
        lootType = new uint32[](items.length);
        tokenContract = new address[](items.length);
        lootId = new uint256[](items.length);
        amount = new uint256[](items.length);
        for (uint256 i = 0; i < items.length; i++) {
            lootType[i] = uint32(items[i].lootType);
            tokenContract[i] = items[i].tokenContract;
            lootId[i] = items[i].lootId;
            amount[i] = items[i].amount;
        }
    }

    /**
     * @dev Converts an array of ILootSystem.Loot to arrays
     */
    function convertMemoryLootToArrays(
        ILootSystem.Loot[] memory items
    )
        internal
        pure
        returns (
            uint32[] memory lootType,
            address[] memory tokenContract,
            uint256[] memory lootId,
            uint256[] memory amount
        )
    {
        lootType = new uint32[](items.length);
        tokenContract = new address[](items.length);
        lootId = new uint256[](items.length);
        amount = new uint256[](items.length);
        for (uint256 i = 0; i < items.length; i++) {
            lootType[i] = uint32(items[i].lootType);
            tokenContract[i] = items[i].tokenContract;
            lootId[i] = items[i].lootId;
            amount[i] = items[i].amount;
        }
    }

    /**
     * @dev Converts LootArrayComponent to LootSystem Loot array
     */
    function convertLootArrayToLootSystem(
        address lootArrayComponent,
        uint256 lootArrayComponentId
    ) internal view returns (ILootSystem.Loot[] memory) {
        // Get the LootArray component values using the LootSetComponent Id
        LootArrayComponent component = LootArrayComponent(lootArrayComponent);
        LootArrayComponentStruct memory lootArrayStruct = component
            .getLayoutValue(lootArrayComponentId);
        // Convert them to an ILootSystem.Loot array
        ILootSystem.Loot[] memory loot = new ILootSystem.Loot[](
            lootArrayStruct.lootType.length
        );
        for (uint256 i = 0; i < lootArrayStruct.lootType.length; i++) {
            loot[i] = ILootSystem.Loot(
                ILootSystem.LootType(lootArrayStruct.lootType[i]),
                lootArrayStruct.tokenContract[i],
                lootArrayStruct.lootId[i],
                lootArrayStruct.amount[i]
            );
        }
        return loot;
    }

    /**
     * @dev Converts LootSystem Loot array to LootArrayComponentStruct
     */
    function convertLootToLootArray(
        ILootSystem.Loot[] memory loot
    ) internal pure returns (LootArrayComponentStruct memory) {
        (
            uint32[] memory lootType,
            address[] memory tokenContract,
            uint256[] memory lootId,
            uint256[] memory amount
        ) = convertMemoryLootToArrays(loot);
        return
            LootArrayComponentStruct(lootType, tokenContract, lootId, amount);
    }

    /** LOOTSYSTEM V2 HELPERS */

    /**
     * @dev Converts an array of ILootSystem.Loot to entity arrays
     */
    function convertMemoryLootToEntityArrays(
        ILootSystemV2.Loot[] memory items
    )
        internal
        pure
        returns (
            uint32[] memory lootType,
            uint256[] memory lootEntity,
            uint256[] memory amount
        )
    {
        lootType = new uint32[](items.length);
        lootEntity = new uint256[](items.length);
        amount = new uint256[](items.length);
        for (uint256 i = 0; i < items.length; i++) {
            lootType[i] = uint32(items[i].lootType);
            lootEntity[i] = items[i].lootEntity;
            amount[i] = items[i].amount;
        }
    }

    /**
     * @dev Converts LootArrayComponent to LootSystem Loot array
     */
    function convertLootEntityArrayToLoot(
        address lootEntityArrayComponent,
        uint256 entity
    ) internal view returns (ILootSystemV2.Loot[] memory) {
        LootEntityArrayComponentStruct
            memory lootEntityArray = LootEntityArrayComponent(
                lootEntityArrayComponent
            ).getLayoutValue(entity);
        // Convert them to an ILootSystem.Loot array
        ILootSystemV2.Loot[] memory loot = new ILootSystemV2.Loot[](
            lootEntityArray.lootType.length
        );
        for (uint256 i = 0; i < lootEntityArray.lootType.length; i++) {
            loot[i] = ILootSystemV2.Loot(
                ILootSystemV2.LootType(lootEntityArray.lootType[i]),
                lootEntityArray.lootEntity[i],
                lootEntityArray.amount[i]
            );
        }
        return loot;
    }

    /**
     * @dev Converts LootSystem Loot array to LootArrayComponentStruct
     */
    function convertLootToLootEntityArray(
        ILootSystemV2.Loot[] memory loot
    ) internal pure returns (LootEntityArrayComponentStruct memory) {
        (
            uint32[] memory lootType,
            uint256[] memory lootEntity,
            uint256[] memory amount
        ) = convertMemoryLootToEntityArrays(loot);
        return LootEntityArrayComponentStruct(lootType, lootEntity, amount);
    }

    function convertTransformInputToLootEntityArray(
        TransformInputComponentStruct memory transformInput
    ) internal pure returns (LootEntityArrayComponentStruct memory) {
        uint32[] memory lootType = new uint32[](
            transformInput.inputType.length
        );
        uint256[] memory lootEntity = new uint256[](
            transformInput.inputType.length
        );
        uint256[] memory amount = new uint256[](
            transformInput.inputType.length
        );
        for (uint256 i = 0; i < transformInput.inputType.length; i++) {
            lootEntity[i] = transformInput.inputEntity[i];
            lootType[i] = transformInput.inputType[i];
            amount[i] = transformInput.amount[i];
        }
        return
            LootEntityArrayComponentStruct({
                lootType: lootType,
                lootEntity: lootEntity,
                amount: amount
            });
    }

    /** INTERNAL */

    /**
     * @dev Handles logic for burning a loot
     * */
    function _burnInput(
        address account,
        address tokenContract,
        uint256 lootId,
        uint256 amount,
        uint32 lootType
    ) internal {
        if (lootType == uint32(ILootSystem.LootType.ERC20)) {
            // Burn amount of ERC20 tokens required to start this bounty
            IGameCurrency(tokenContract).burn(account, amount);
        } else if (lootType == uint32(ILootSystem.LootType.ERC1155)) {
            // Burn amount of ERC1155 tokens required to start this bounty
            IGameItems(tokenContract).burn(account, lootId, amount);
        }
    }
}
