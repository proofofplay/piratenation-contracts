// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ITraitsProvider, TraitDataType} from "../interfaces/ITraitsProvider.sol";

/** Trait checking structs */

// Type of check to perform for a trait
enum TraitCheckType {
    UNDEFINED,
    TRAIT_EQ,
    TRAIT_GT,
    TRAIT_LT,
    TRAIT_LTE,
    TRAIT_GTE,
    EXIST,
    NOT_EXIST
}

// A single trait value check
struct TraitCheck {
    // Type of check to perform
    TraitCheckType checkType;
    // Id of the trait to check a value for
    uint256 traitId;
    // Trait value, value to compare against for trait check
    int256 traitValue;
}

/** @title Common traits types and related functions for the game **/
library TraitsLibrary {
    /** ERRORS **/

    /// @notice Invalid trait check type
    error InvalidTraitCheckType(TraitCheckType checkType);

    /// @notice Trait was not equal
    error TraitCheckFailed(TraitCheckType checkType);

    /// @notice Trait check was not for a int-compatible type
    error ExpectedIntForTraitCheck();

    /**
     * Performs a trait value check against a given token
     *
     * @param traitsProvider Reference to the traits contract
     * @param traitCheck Trait check to perform
     * @param tokenContract Address of the token
     * @param tokenId Id of the token
     */
    function performTraitCheck(
        ITraitsProvider traitsProvider,
        TraitCheck memory traitCheck,
        address tokenContract,
        uint256 tokenId
    ) internal view returns (bool) {
        TraitCheckType checkType = traitCheck.checkType;

        // Existence check
        bool hasTrait = traitsProvider.hasTrait(
            tokenContract,
            tokenId,
            traitCheck.traitId
        );

        if (checkType == TraitCheckType.NOT_EXIST && hasTrait == true) {
            return false;
        }

        // If is missing trait, return false immediately
        if (hasTrait == false) {
            return false;
        }

        // Numeric checks only
        int256 traitValue;

        TraitDataType dataType = traitsProvider
            .getTraitMetadata(traitCheck.traitId)
            .dataType;

        if (dataType == TraitDataType.UINT) {
            traitValue = SafeCast.toInt256(
                traitsProvider.getTraitUint256(
                    tokenContract,
                    tokenId,
                    traitCheck.traitId
                )
            );
        } else if (dataType == TraitDataType.INT) {
            traitValue = traitsProvider.getTraitInt256(
                tokenContract,
                tokenId,
                traitCheck.traitId
            );
        } else if (dataType == TraitDataType.INT) {
            traitValue = traitsProvider.getTraitBool(
                tokenContract,
                tokenId,
                traitCheck.traitId
            )
                ? int256(1)
                : int256(0);
        } else {
            revert ExpectedIntForTraitCheck();
        }

        if (checkType == TraitCheckType.TRAIT_EQ) {
            return traitValue == traitCheck.traitValue;
        } else if (checkType == TraitCheckType.TRAIT_GT) {
            return traitValue > traitCheck.traitValue;
        } else if (checkType == TraitCheckType.TRAIT_GTE) {
            return traitValue >= traitCheck.traitValue;
        } else if (checkType == TraitCheckType.TRAIT_LT) {
            return traitValue < traitCheck.traitValue;
        } else if (checkType == TraitCheckType.TRAIT_LTE) {
            return traitValue <= traitCheck.traitValue;
        } else if (checkType == TraitCheckType.EXIST) {
            return true;
        }

        // Default to not-pass / error
        revert InvalidTraitCheckType(checkType);
    }

    /**
     * Performs a trait value check against a given token
     *
     * @param traitsProvider Reference to the traits contract
     * @param traitCheck Trait check to perform
     * @param tokenContract Address of the token
     * @param tokenId Id of the token
     */
    function requireTraitCheck(
        ITraitsProvider traitsProvider,
        TraitCheck memory traitCheck,
        address tokenContract,
        uint256 tokenId
    ) internal view {
        bool success = performTraitCheck(
            traitsProvider,
            traitCheck,
            tokenContract,
            tokenId
        );
        if (!success) {
            revert TraitCheckFailed(traitCheck.checkType);
        }
    }
}
