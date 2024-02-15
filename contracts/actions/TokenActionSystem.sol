// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {MANAGER_ROLE} from "../Constants.sol";

import {ITokenActionSystem, ID} from "./ITokenActionSystem.sol";
import {ITokenAction} from "./ITokenAction.sol";

import {IGameItems} from "../tokens/gameitems/IGameItems.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";

/**
 * @title TokenActionSystem
 *
 * Gives tokens the ability to perform actions
 */
contract TokenActionSystem is
    ITokenActionSystem,
    GameRegistryConsumerUpgradeable
{
    // Common properties of a token action
    struct ActionProps {
        // Whether or not action is enabled
        bool enabled;
        // Whether or not to burn the token after use
        bool consumable;
        // Static initialization data for the action
        bytes initData;
    }

    /// @notice Mapping of token actions
    mapping(uint256 => ITokenAction) private _tokenActionContracts;

    /// @notice (tokenContract => tokenId => actionId => ActionProps)
    mapping(address => mapping(uint256 => mapping(uint256 => ActionProps))) _tokenActions;

    /** EVENTS **/

    /// @notice Emitted when an token action has been registered
    event RegisterTokenAction(
        uint256 actionId,
        string actionName,
        address tokenActionContract
    );

    /// @notice Emitted when an token action has been updated
    event SetActionForToken(
        address tokenContract,
        uint256 tokenId,
        uint256 actionId
    );

    /// @notice Emitted when a token action has been taken
    event PerformGameItemAction(
        address account,
        address tokenContract,
        uint256 tokenId,
        uint256 amount,
        uint256 actionId
    );

    /** ERRORS **/

    /// @notice Action needs to be registered before being added to a token
    error ActionNotRegistered(uint256 actionId);

    /// @notice Action has not been enabled for the given token contract
    error ActionNotEnabled(uint256 actionId);

    /// @notice Account does not have enough tokens
    error NotEnoughTokens(uint256 expected, uint256 actual);

    /// @notice Init data was invalid
    error InvalidInitData(uint256 actionId);

    /** SETUP **/

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /** EXTERNAL **/

    /**
     * Register a new token action contract
     * @param actionName Name of the action
     * @param tokenActionContract Action contract to register
     */
    function registerTokenActionContract(
        string calldata actionName,
        address tokenActionContract
    ) external onlyRole(MANAGER_ROLE) {
        bytes32 actionBytes = keccak256(bytes(actionName));
        uint256 actionId = uint256(actionBytes);
        _tokenActionContracts[actionId] = ITokenAction(tokenActionContract);
        emit RegisterTokenAction(actionId, actionName, tokenActionContract);
    }

    /**
     * @param actionId Id of the action to get the registered contract for
     * @return Returns the token action contract for the given actionId
     */
    function getTokenActionContract(uint256 actionId)
        external
        view
        returns (ITokenAction)
    {
        return _tokenActionContracts[actionId];
    }

    /**
     * @param tokenContract Address of the token contract
     * @param tokenId       Id of the token contract
     * @param actionId      Id of the action to add
     * @return Action properties for the given token and action
     */
    function getActionForToken(
        address tokenContract,
        uint256 tokenId,
        uint256 actionId
    ) external view returns (ActionProps memory) {
        return _tokenActions[tokenContract][tokenId][actionId];
    }

    /**
     * Adds a new action to a given token
     *
     * @param tokenContract Address of the token contract
     * @param tokenId       Id of the token contract
     * @param actionId      Id of the action to add
     * @param actionProps   Properties of the action
     */
    function setActionForToken(
        address tokenContract,
        uint256 tokenId,
        uint256 actionId,
        ActionProps calldata actionProps
    ) external onlyRole(MANAGER_ROLE) {
        ITokenAction tokenActionContract = _tokenActionContracts[actionId];
        if (address(tokenActionContract) == address(0)) {
            revert ActionNotRegistered(actionId);
        }

        _tokenActions[tokenContract][tokenId][actionId] = actionProps;

        // Validate initData
        if (
            tokenActionContract.isInitDataValid(actionProps.initData) == false
        ) {
            revert InvalidInitData(actionId);
        }

        emit SetActionForToken(tokenContract, tokenId, actionId);
    }

    /**
     * Performs a given action for a game item
     *
     * @param tokenContract Address of the game item contract
     * @param tokenId       Id of the token performing the action
     * @param actionId      Id of the action being performed
     * @param runtimeData   Extra ABI encoded call-specific data needed to perform the action
     */
    function performGameItemAction(
        address tokenContract,
        uint256 tokenId,
        uint256 amount,
        uint256 actionId,
        bytes memory runtimeData
    ) external nonReentrant whenNotPaused {
        address account = _getPlayerAccount(_msgSender());

        // Get the action contract
        ITokenAction tokenAction = _tokenActionContracts[actionId];
        if (address(tokenAction) == address(0)) {
            revert ActionNotRegistered(actionId);
        }

        // Make sure action is valid for this token
        ActionProps storage actionProps = _tokenActions[tokenContract][tokenId][
            actionId
        ];
        if (!actionProps.enabled) {
            revert ActionNotEnabled(actionId);
        }

        // Make sure user has the items
        IGameItems gameItems = IGameItems(tokenContract);
        uint256 balance = gameItems.balanceOf(account, tokenId);
        if (amount > balance) {
            revert NotEnoughTokens(amount, balance);
        }

        // Burn token
        if (actionProps.consumable) {
            IGameItems(tokenContract).burn(account, tokenId, amount);
        }

        // Perform action
        tokenAction.performGameItemAction(
            account,
            tokenContract,
            tokenId,
            amount,
            actionProps.initData,
            runtimeData
        );

        // Emit event
        emit PerformGameItemAction(
            account,
            tokenContract,
            tokenId,
            amount,
            actionId
        );
    }
}
