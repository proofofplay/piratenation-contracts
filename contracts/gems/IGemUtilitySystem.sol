// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

uint256 constant ID = uint256(keccak256("game.piratenation.gemutilitysystem"));

import {TransformParams} from "../transform/ITransformRunnerSystem.sol";

/// @title Interface for the GemUtilitySystem
interface IGemUtilitySystem {
    /**
     * @dev Start a transform, fulfill missing resources or energy with gems
     */
    function gemStartTransform(
        TransformParams calldata input,
        uint256 expectedGemCost
    ) external returns (uint256);

    /**
     * @dev Complete a transform, fulfill missing resources, cooldowns, energy with gems
     */
    function gemCompleteTransform(
        uint256 transformInstanceEntity,
        uint256 expectedGemCost
    ) external;

    /**
     * @dev Remove cooldown from a transform
     */
    function gemTransformCooldownRemoval(
        uint256 transformEntity,
        uint256 expectedGemCost
    ) external;
}
