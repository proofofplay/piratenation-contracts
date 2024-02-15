// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {ITokenAction} from "../actions/ITokenAction.sol";

import {ID as GOLDTOKEN_ID, IGameCurrency} from "../tokens/goldtoken/IGoldToken.sol";

import {GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";

import "../GameRegistryConsumerUpgradeable.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.tokenactionmock"));

/**
 * ITokenAction that gives the user some energy
 */
contract TokenActionMock is ITokenAction, GameRegistryConsumerUpgradeable {
    /** SETUP **/

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * Validates initialization data to ensure it can be used
     *
     * @param initData Data used to initialize the action before calling
     */
    function isInitDataValid(
        bytes memory initData
    ) external pure override returns (bool) {
        uint256 goldToGrant = abi.decode(initData, (uint256));

        return goldToGrant > 0;
    }

    /** EXTERNAL **/

    /**
     * @inheritdoc ITokenAction
     */
    function performGameItemAction(
        address account,
        address,
        uint256,
        uint256 amount,
        bytes memory initData,
        bytes memory
    ) external override onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        uint256 goldToGrant = abi.decode(initData, (uint256));

        // Give the player 10 gold
        IGameCurrency goldToken = IGameCurrency(_getSystem(GOLDTOKEN_ID));
        goldToken.mint(account, goldToGrant * amount);
    }
}
