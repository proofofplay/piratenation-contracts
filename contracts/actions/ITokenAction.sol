// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

/**
 * Generic interface to let a token perform a given action
 */
interface ITokenAction {
    /**
     * Validates initialization data to ensure it can be used
     *
     * @param initData Data used to initialize the action before calling
     */
    function isInitDataValid(bytes memory initData)
        external
        view
        returns (bool);

    /**
     * Performs the action for a game item
     *
     * @param account               Account performing the action
     * @param tokenContract         Token contract
     * @param tokenId               Id of the token performing the action
     * @param amount                Amount of tokens to perform action with
     * @param initData              Data used to initialize the action
     * @param runtimeData           Data used to run the action
     */
    function performGameItemAction(
        address account,
        address tokenContract,
        uint256 tokenId,
        uint256 amount,
        bytes memory initData,
        bytes memory runtimeData
    ) external;
}
