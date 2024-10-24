// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import {ILootSystemV2} from "../loot/ILootSystemV2.sol";
import {Layout as TransformInstanceComponentLayout} from "../generated/components/TransformInstanceComponent.sol";

struct TransformParams {
    // Transform to start
    uint256 transformEntity;
    // Inputs to the transform
    ILootSystemV2.Loot[] inputs;
    // Number of times to run the transform
    uint16 count;
    // Extra encoded data to pass to the transform
    bytes data;
}

/// @title Interface for the TransformSystem that lets players go on transforms
interface ITransformRunnerSystem {
    /**
     * Start a transform for the given account
     *
     * @param transformInstance Transform instance that was created
     * @param transformInstanceEntity Entity of transform instance being started
     * @param params Transform parameters
     *
     * @return needsVrf Whether or not the transform needs vrf to complete
     * @return skipTransformInstance Whether or not the transform instance should be skipped
     */
    function startTransform(
        TransformInstanceComponentLayout memory transformInstance,
        uint256 transformInstanceEntity,
        TransformParams calldata params
    ) external returns (bool needsVrf, bool skipTransformInstance);

    /**
     * Complete a transform for the given account
     *
     * @param transformInstanceEntity Entity of transform instance being completed
     * @param randomWord Random word to use for the transform completion
     *
     * @return numSuccess How many transforms were successful
     * @return nextRandomWord Next random word to use
     */
    function completeTransform(
        TransformInstanceComponentLayout memory transformInstance,
        uint256 transformInstanceEntity,
        uint256 randomWord
    ) external returns (uint16 numSuccess, uint256 nextRandomWord);

    /**
     * Callback for after the transform has completed
     *
     * @param transformInstance Transform instance that was completed
     * @param randomWord Random word to use for randomness
     *
     * @return Updated random word if it was changed
     */
    function onTransformComplete(
        TransformInstanceComponentLayout memory transformInstance,
        uint256 transformInstanceEntity,
        uint256 randomWord
    ) external returns (uint256);

    /**
     * Whether or not a given transform is available to the given player
     *
     * @param account Account to check if transform is available for
     * @param params Params used to start the transform
     *
     * @return Whether or not the transform is available to the given account
     */
    function isTransformAvailable(
        address account,
        TransformParams calldata params
    ) external view returns (bool);

    /**
     * Whether or not the given transform is completeable
     *
     * @param transformInstance Component data for teh transform instance
     *
     * @return Whether or not the transform is completeable
     */
    function isTransformCompleteable(
        TransformInstanceComponentLayout memory transformInstance
    ) external view returns (bool);
}
