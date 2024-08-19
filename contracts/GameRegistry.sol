// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@opengsn/contracts/src/interfaces/IERC2771Recipient.sol";

import {PAUSER_ROLE, RANDOMIZER_ROLE, DEPOSITOR_ROLE, MANAGER_ROLE, MINTER_ROLE, GAME_CURRENCY_CONTRACT_ROLE, GAME_NFT_CONTRACT_ROLE, GAME_ITEMS_CONTRACT_ROLE, GAME_LOGIC_CONTRACT_ROLE, TRUSTED_FORWARDER_ROLE, DEPLOYER_ROLE, TRUSTED_MULTICHAIN_ORACLE_ROLE} from "./Constants.sol";
import "./core/IGameRegistry.sol";
import {EntityLibrary} from "./core/EntityLibrary.sol";
import {IComponent} from "./core/components/IComponent.sol";
import {GUIDLibrary} from "./core/GUIDLibrary.sol";
import {GuidCounterComponent, ID as GUID_COUNTER_COMPONENT_ID} from "./generated/components/GuidCounterComponent.sol";
import {IMultichain1155} from "./tokens/IMultichain1155.sol";
import {IMultichain721} from "./tokens/IMultichain721.sol";
import {ChainIdComponent, ID as CHAIN_ID_COMPONENT_ID} from "./generated/components/ChainIdComponent.sol";

// NOTE: Do NOT change ID if we wish to keep multi-chain GUID's in the same namespace
uint256 constant ID = uint256(keccak256("game.piratenation.gameregistry.v1"));
uint80 constant GUID_PREFIX = uint80(ID);

struct BatchComponentData {
    uint256[] entities;
    uint256[] componentIds;
    bytes[] data;
}

/** @title Contract to track and limit access by accounts in the same block */
contract GameRegistry is
    AccessControlUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    IERC2771Recipient,
    IGameRegistry
{
    /// @notice Block limit on transmitting a signed operator registration message
    uint256 public constant OPERATOR_MESSAGE_BLOCK_LIMIT = 30; // 30 blocks

    /// @notice Operator registration cooldown time in secons
    uint256 public constant REGISTER_OPERATOR_COOLDOWN_LIMIT = 60 * 2; // 2 minutes

    /** LIBRARY METHODS **/

    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    /** TYPES **/

    /// @notice Player Account structure
    struct PlayerAccount {
        address playerAddress;
        uint256 expiration;
    }

    /** MEMBERS **/

    /// @notice Last time the player registered an operator wallet
    mapping(address => uint256) public lastRegisterOperatorTime;

    /// @notice System registry
    mapping(uint256 => address) private _systemRegistry;

    /// @notice Registry of current operator address to the player account
    mapping(address => PlayerAccount) private _operatorToPlayerAccount;

    /// @notice Registry of player account mapped to authorized operators
    mapping(address => EnumerableSet.AddressSet)
        private _playerToOperatorAddresses;

    /// @notice Map component id to its contract address
    mapping(uint256 => address) _componentIdToAddress;

    /// @notice Map component address to its ID
    mapping(address => uint256) _componentAddressToId;

    /// @notice GUID Counter
    uint96 private _guidCounter;

    /// @notice Map component ID to a map of the entities it stores
    mapping(uint256 => EnumerableSet.UintSet) private _entityToComponents;

    /// @notice Flag to check if the GUID counter has been set
    bool private _guidCounterSet;

    // @notice RequestID Mapping for cross-chain transfers
    mapping(uint256 => bool) public requestIdProcessed;

    /** EVENTS **/

    /// @notice Emitted when an Operator address is registered
    event OperatorRegistered(
        address player,
        address operator,
        uint256 expiration
    );

    /// @notice Emitted when a System address is registered
    event SystemRegistered(uint256 indexed id, address indexed systemAddress);

    /// @notice Emitted when an Operator address is removed
    event OperatorDeregistered(address operator, address player);

    /// @notice Emitted when a component has been registered
    event ComponentRegistered(
        uint256 indexed componentId,
        address indexed componentAddress
    );

    /// @notice Emitted when a component value has been set
    event ComponentValueSet(
        uint256 indexed componentId,
        uint256 indexed entity,
        bytes data
    );

    /// @notice Emitted when a component value has been removed
    event ComponentValueRemoved(
        uint256 indexed componentId,
        uint256 indexed entity
    );

    /// @notice Emitted when a batch of component values has been set
    event BatchComponentValueSet(
        uint256 indexed componentId,
        uint256[] entities,
        bytes[] data
    );

    /// @notice Emitted when a batch of component values has been removed
    event BatchComponentValueRemoved(
        uint256 indexed componentId,
        uint256[] entities
    );

    /// @notice Emitted when a batch of component values has been set
    event BatchMultiComponentValueSet(
        uint256[] componentIds,
        uint256[] entities,
        bytes[] data
    );

    /// @notice Emitted when a batch of component values has been removed
    event BatchMultiComponentValueRemoved(
        uint256[] componentIds,
        uint256[] entities
    );

    /// @notice Emitted when a ComponentValueSet should be mirrored across chains
    event PublishComponentValueSet(
        uint256 indexed requestId,
        uint256 indexed componentId,
        uint256 indexed entity,
        uint256 chainId,
        uint256 requestTime,
        bytes data
    );

    /// @notice Emitted when a BatchComponentValueSet should be mirrored across chains
    event PublishBatchComponentValueSet(
        uint256 indexed requestId,
        uint256 indexed componentId,
        uint256 chainId,
        uint256 requestTime,
        uint256[] entities,
        bytes[] data
    );

    /// @notice Emitted when a BatchComponentValueSet should be mirrored across chains
    event PublishBatchSetComponentValue(
        uint256 indexed requestId,
        uint256[] componentIds,
        uint256[] entities,
        uint256 fromChainId,
        uint256 requestTime,
        bytes[] data
    );

    /// @notice Emitted when a ComponentValueRemoved should be mirrored across chains
    // TODO: Reenable when we're ready to support cross-chain removal
    // event PublishComponentValueRemoved(
    //     uint256 indexed requestId,
    //     uint256 indexed componentId,
    //     uint256 indexed entity,
    //     uint256 chainId,
    //     uint256 requestTime
    // );

    /// @notice Emitted when a BatchComponentValueRemoved should be mirrored across chains
    // TODO: Reenable when we're ready to support cross-chain removal
    // event PublishBatchComponentValueRemoved(
    //     uint256 indexed requestId,
    //     uint256 indexed componentId,
    //     uint256 chainId,
    //     uint256 requestTime,
    //     uint256[] entities
    // );

    // 1155 Events
    event Multichain1155TransferSingleSent(
        uint256 requestId,
        uint256 indexed systemId,
        address indexed from,
        address indexed to,
        uint256 toChainId,
        uint256 id,
        uint256 amount
    );

    event Multichain1155TransferSingleReceived(
        uint256 requestId,
        uint256 indexed systemId,
        address indexed from,
        address indexed to,
        uint256 fromChainId,
        uint256 id,
        uint256 amount
    );

    event Multichain1155TransferBatchSent(
        uint256 requestId,
        uint256 indexed systemId,
        address indexed from,
        address indexed to,
        uint256 toChainId,
        uint256[] ids,
        uint256[] amounts
    );

    event Multichain1155TransferBatchReceived(
        uint256 requestId,
        uint256 indexed systemId,
        address indexed from,
        address indexed to,
        uint256 fromChainId,
        uint256[] ids,
        uint256[] amounts
    );

    // 721 events
    event Multichain721TransferSent(
        uint256 requestId,
        uint256 indexed systemId,
        address indexed from,
        address indexed to,
        uint256 tokenId,
        uint256 toChainId
    );

    event Multichain721TransferReceived(
        uint256 requestId,
        uint256 indexed systemId,
        address indexed from,
        address indexed to,
        uint256 tokenId,
        uint256 toChainId
    );

    /** ERRORS **/

    /// @notice Invalid data count compared to number of entity count
    error InvalidBatchData(uint256 entityCount, uint256 dataCount);

    /// @notice Trying to access a component that hasn't been previously registered
    error ComponentNotRegistered(address component);

    /// @notice Trying to access a componentId that hasn't been previously registered
    error ComponentIdNotRegistered(uint256 componentId);

    /// @notice Operator
    error InvalidOperatorAddress();

    /// @notice Operator address must send transaction
    error InvalidCaller();

    /// @notice Player does not match signature
    error PlayerSignerMismatch(address expected, address actual);

    /// @notice Operator is registered to a different address, deregister first
    error OperatorAlreadyRegistered();

    /// @notice Invalid expiration timestamp provided
    error InvalidExpirationTimestamp();

    /// @notice Invalid block number (future block)
    error InvalidBlockNumber();

    /// @notice Invalid block number (expired)
    error InvalidExpirationBlockNumber();

    /// @notice Degregister request must come from player or operator
    error InvalidDeregisterCaller();

    /// @notice Operator has already expired
    error OperatorExpired();

    /// @notice Operator was not registered
    error OperatorNotRegistered();

    /// @notice Register operator in cooldown
    error RegisterOperatorInCooldown();

    /// @notice Not authorized to perform action
    error MissingRole(address account, bytes32 expectedRole);

    /// @notice Guid counter already set
    error GuidCounterSet();

    /// @notice Invalid System ID - The system ID must be registered.
    error InvalidSystem(uint256 systemId);

    /// @notice Invalid Chain ID - Must be processed on the correct Chain
    error InvalidChain(uint256 chainId);

    /// @notice Already Processed this request
    error AlreadyProcessed(uint256 requestId);

    /** SETUP **/

    /**
     * Initializer for this upgradeable contract
     */
    function initialize(address admin) public initializer {
        __AccessControl_init();
        __Ownable_init();
        __Pausable_init();

        // Move ownership to deployer
        _transferOwnership(admin);

        // Give admin access role to owner
        _setupRole(DEFAULT_ADMIN_ROLE, admin);

        _setRoleAdmin(PAUSER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(RANDOMIZER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(DEPOSITOR_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(DEPLOYER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(GAME_NFT_CONTRACT_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(GAME_CURRENCY_CONTRACT_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(GAME_ITEMS_CONTRACT_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(GAME_LOGIC_CONTRACT_ROLE, DEFAULT_ADMIN_ROLE);

        _pause();
    }

    /** EXTERNAL **/

    /**
     * @dev Set the GUID counter, should only be called once
     */
    function setGuidCounter(uint96 guidValue) external onlyRole(MANAGER_ROLE) {
        if (_guidCounterSet) {
            revert GuidCounterSet();
        }
        _guidCounterSet = true;
        _guidCounter = guidValue;
    }

    /**
     * @dev Get the GUID counter value
     */
    function getGuidCounter() external view returns (uint96) {
        return _guidCounter;
    }

    /**
     * Pause/Unpause the game and ALL the systems that utilize this game
     *
     * @param _paused Whether or pause or unpause
     */
    function setPaused(bool _paused) external {
        if (_msgSender() == owner() || hasRole(PAUSER_ROLE, _msgSender())) {
            if (_paused) {
                _pause();
            } else {
                _unpause();
            }
        } else {
            revert MissingRole(_msgSender(), PAUSER_ROLE);
        }
    }

    /**
     * @inheritdoc IGameRegistry
     */
    function paused()
        public
        view
        override(IGameRegistry, PausableUpgradeable)
        returns (bool)
    {
        return PausableUpgradeable.paused();
    }

    /**
     * @inheritdoc IGameRegistry
     */
    function registerSystem(
        uint256 systemId,
        address systemAddress
    ) external onlyRole(DEPLOYER_ROLE) {
        _systemRegistry[systemId] = systemAddress;

        emit SystemRegistered(systemId, systemAddress);
    }

    /**
     * @inheritdoc IGameRegistry
     */
    function getSystem(uint256 systemId) external view returns (address) {
        return _systemRegistry[systemId];
    }

    /**
     * @inheritdoc IGameRegistry
     */
    function registerComponent(
        uint256 componentId,
        address componentAddress
    ) public {
        if (
            hasAccessRole(GAME_LOGIC_CONTRACT_ROLE, _msgSender()) == false &&
            hasAccessRole(MANAGER_ROLE, _msgSender()) == false &&
            hasAccessRole(DEFAULT_ADMIN_ROLE, _msgSender()) == false
        ) {
            revert MissingRole(_msgSender(), GAME_LOGIC_CONTRACT_ROLE);
        }

        _componentIdToAddress[componentId] = componentAddress;
        _componentAddressToId[componentAddress] = componentId;
        emit ComponentRegistered(componentId, componentAddress);
    }

    /**
     * Gets a raw entity component value
     * @param entity Entity to get value for
     * @param componentId Component to get value from
     *
     * @return Bytes value of the entity component
     */

    function getComponentValue(
        uint256 entity,
        uint256 componentId
    ) external view returns (bytes memory) {
        address componentAddress = _componentIdToAddress[componentId];
        if (componentAddress == address(0)) {
            revert ComponentNotRegistered(componentAddress);
        }
        return IComponent(componentAddress).getBytes(entity);
    }

    /**
     * @inheritdoc IGameRegistry
     * @dev Only registered components can call this function, otherwise it will revert
     */
    function batchGetComponentValues(
        uint256[] calldata entities,
        uint256[] calldata componentIds
    ) external view returns (bytes[] memory values) {
        values = new bytes[](entities.length);
        for (uint256 i = 0; i < entities.length; i++) {
            address componentAddress = _componentIdToAddress[componentIds[i]];
            if (componentAddress == address(0)) {
                revert ComponentNotRegistered(componentAddress);
            }
            values[i] = IComponent(componentAddress).getBytes(entities[i]);
        }
    }

    /**
     * @inheritdoc IGameRegistry
     */
    function batchSetComponentValue(
        uint256[] calldata entities,
        uint256[] calldata componentIds,
        bytes[] calldata values
    ) external override {
        if (
            hasAccessRole(GAME_LOGIC_CONTRACT_ROLE, _msgSender()) == false &&
            hasAccessRole(MANAGER_ROLE, _msgSender()) == false &&
            owner() != _msgSender()
        ) {
            revert MissingRole(_msgSender(), GAME_LOGIC_CONTRACT_ROLE);
        }

        _batchSetComponentValue(entities, componentIds, values);
    }

    /**
     * @inheritdoc IGameRegistry
     */
    function batchPublishSetComponentValue(
        uint256[] calldata entities,
        uint256[] calldata componentIds,
        bytes[] calldata values
    ) external override returns (uint256 requestId) {
        if (
            hasAccessRole(GAME_LOGIC_CONTRACT_ROLE, _msgSender()) == false &&
            hasAccessRole(MANAGER_ROLE, _msgSender()) == false &&
            owner() != _msgSender()
        ) {
            revert MissingRole(_msgSender(), GAME_LOGIC_CONTRACT_ROLE);
        }

        _batchSetComponentValue(entities, componentIds, values);

        requestId = _generateGUID();
 
        emit PublishBatchSetComponentValue(
            requestId,
            componentIds,
            entities,
            block.chainid,
            block.timestamp,
            values
        );

        return requestId;
    }

    /**
     * @inheritdoc IGameRegistry
     * @dev Only registered components can call this function, otherwise it will revert
     */
    function registerComponentValueSet(
        uint256 entity,
        bytes calldata data
    ) external virtual {
        // Only registered components can call this function, if the component isn't register the event won't be emitted
        uint256 componentId = _componentAddressToId[msg.sender];
        if (componentId == 0) {
            revert ComponentNotRegistered(msg.sender);
        }

        // Store reference of entity to component
        _entityToComponents[entity].add(componentId);

        emit ComponentValueSet(componentId, entity, data);
    }

    /**
     * @inheritdoc IGameRegistry
     * @dev Only registered components can call this function, otherwise it will revert
     */
    function publishComponentValueSet(
        uint256 componentId,
        uint256 entity,
        bytes calldata data
    )
        external
        virtual
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (uint256 requestId)
    {
        if (_componentIdToAddress[componentId] == address(0)) {
            revert ComponentIdNotRegistered(componentId);
        }

        requestId = _generateGUID();
        emit PublishComponentValueSet(
            requestId,
            componentId,
            entity,
            block.chainid,
            block.timestamp,
            data
        );
    }

    /**
     * @inheritdoc IGameRegistry
     * @dev Only registered components can call this function, otherwise it will revert
     */
    function batchRegisterComponentValueSet(
        uint256[] calldata entities,
        bytes[] calldata data
    ) external virtual {
        // Check to make sure the component is registered
        uint256 componentId = _componentAddressToId[msg.sender];
        if (componentId == 0) {
            revert ComponentNotRegistered(msg.sender);
        }
        if (entities.length != data.length) {
            revert InvalidBatchData(entities.length, data.length);
        }

        // Store references of entities to component
        for (uint256 i = 0; i < entities.length; i++) {
            _entityToComponents[entities[i]].add(componentId);
        }

        emit BatchComponentValueSet(componentId, entities, data);
    }

    /**
     * @inheritdoc IGameRegistry
     * @dev Only registered components can call this function, otherwise it will revert
     */
    function batchPublishComponentValueSet(
        uint256 componentId,
        uint256[] calldata entities,
        bytes[] calldata data
    )
        external
        virtual
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (uint256 requestId)
    {
        if (_componentIdToAddress[componentId] == address(0)) {
            revert ComponentIdNotRegistered(componentId);
        }

        // Check to make sure the component is registered
        if (entities.length != data.length) {
            revert InvalidBatchData(entities.length, data.length);
        }

        requestId = _generateGUID();
        emit PublishBatchComponentValueSet(
            requestId,
            componentId,
            block.chainid,
            block.timestamp,
            entities,
            data
        );
    }

    /**
     * @inheritdoc IGameRegistry
     * @dev Only registered components can call this function, otherwise it will revert
     */
    function registerComponentValueRemoved(uint256 entity) external virtual {
        // Only registered components can call this function, if the component isn't register the event won't be emitted
        uint256 componentId = _componentAddressToId[msg.sender];
        if (componentId == 0) {
            revert ComponentNotRegistered(msg.sender);
        }

        // Remove reference of entity to component
        _entityToComponents[entity].remove(componentId);

        emit ComponentValueRemoved(componentId, entity);
    }

    /**
     * @inheritdoc IGameRegistry
     * @dev Only registered components can call this function, otherwise it will revert
     */
    function batchRegisterComponentValueRemoved(
        uint256[] calldata entities
    ) external virtual {
        uint256 componentId = _componentAddressToId[msg.sender];
        if (componentId == 0) {
            revert ComponentNotRegistered(msg.sender);
        }

        // Store references of entities to component
        for (uint256 i = 0; i < entities.length; i++) {
            _entityToComponents[entities[i]].remove(componentId);
        }

        emit BatchComponentValueRemoved(componentId, entities);
    }

    /**
     * @notice Emits an event which oracles pick up to mint the item on another chian.
     * @dev Only registered components can call this function, otherwise it will revert
     */
    function sendMultichain1155TransferSingle(
        uint256 systemId,
        address from,
        address to,
        uint256 toChainId,
        uint256 id,
        uint256 amount
    ) external onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        if (to == address(0)) {
            return;
        }
        uint256 requestId = _generateGUID();

        if (address(_systemRegistry[systemId]) != msg.sender) {
            revert InvalidSystem(systemId);
        }
        emit Multichain1155TransferSingleSent(
            requestId,
            systemId,
            from,
            to,
            toChainId,
            id,
            amount
        );
    }

    /**
     * @notice Emits an event which oracles pick up to mint the item on another chian.
     * @dev Only registered components can call this function, otherwise it will revert
     */
    function sendMultichain1155TransferBatch(
        uint256 systemId,
        address from,
        address to,
        uint256 toChainId,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        if (to == address(0)) {
            return;
        }
        uint256 requestId = _generateGUID();

        if (address(_systemRegistry[systemId]) != msg.sender) {
            revert InvalidSystem(systemId);
        }
        emit Multichain1155TransferBatchSent(
            requestId,
            systemId,
            from,
            to,
            toChainId,
            ids,
            amounts
        );
    }

    /**
     * @notice Emits an event which oracles pick up to mint the item on another chian.
     * @dev Only registered components can call this function, otherwise it will revert
     */
    function sendMultichain721Transfer(
        uint256 systemId,
        address from,
        address to,
        uint256 tokenId,
        uint256 toChainId
    ) external onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        if (to == address(0)) {
            return;
        }
        uint256 requestId = _generateGUID();

        if (address(_systemRegistry[systemId]) != msg.sender) {
            revert InvalidSystem(systemId);
        }
        emit Multichain721TransferSent(
            requestId,
            systemId,
            from,
            to,
            tokenId,
            toChainId
        );
    }

    /**
     * @notice Delivers an item that has been transferred from another chain in the Multichain
     * @dev Must be called by a trusted multichain
     */
    function deliverMultichain1155TransferSingle(
        uint256 requestId,
        uint256 systemId,
        address from,
        address to,
        uint256 fromChainId,
        uint256 id,
        uint256 amount
    ) external onlyRole(TRUSTED_MULTICHAIN_ORACLE_ROLE) {
        _enforceChain(to);

        //replay protection
        _validateRequestId(requestId);

        // mint items
        if (_systemRegistry[systemId] == address(0)) {
            revert InvalidSystem(systemId);
        }
        IMultichain1155 system = IMultichain1155(_systemRegistry[systemId]);
        system.receivedMultichain1155TransferSingle(to, id, amount);

        emit Multichain1155TransferSingleReceived(
            requestId,
            systemId,
            from,
            to,
            fromChainId,
            id,
            amount
        );
    }

    /**
     * @notice Delivers an item that has been transferred from another chain in the Multichain
     * @dev Must be called by a trusted multichain
     */
    function deliverMultichain1155TransferBatch(
        uint256 requestId,
        uint256 systemId,
        address from,
        address to,
        uint256 fromChainId,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external onlyRole(TRUSTED_MULTICHAIN_ORACLE_ROLE) {
        _enforceChain(to);

        //replay protection
        _validateRequestId(requestId);

        // mint items
        if (_systemRegistry[systemId] == address(0)) {
            revert InvalidSystem(systemId);
        }
        IMultichain1155 system = IMultichain1155(_systemRegistry[systemId]);
        system.receivedMultichain1155TransferBatch(to, ids, amounts);

        emit Multichain1155TransferBatchReceived(
            requestId,
            systemId,
            from,
            to,
            fromChainId,
            ids,
            amounts
        );
    }

    /**
     * @notice Delivers an item that has been transferred from another chain in the Multichain
     * @dev Must be called by a trusted multichain
     */
    function deliverMultichain721Transfer(
        uint256 requestId,
        uint256 systemId,
        address from,
        address to,
        uint256 tokenId,
        uint256 fromChainId,
        BatchComponentData calldata componentData
    ) external onlyRole(TRUSTED_MULTICHAIN_ORACLE_ROLE) {
        _enforceChain(to);

        _validateRequestId(requestId);

        if (_systemRegistry[systemId] == address(0)) {
            revert InvalidSystem(systemId);
        }
        // mint items
        IMultichain721 system = IMultichain721(_systemRegistry[systemId]);
        system.receivedMultichain721Transfer(to, tokenId);

        _batchSetComponentData(componentData);

        emit Multichain721TransferReceived(
            requestId,
            systemId,
            from,
            to,
            tokenId,
            fromChainId
        );
    }

    /**
     * @inheritdoc IGameRegistry
     */
    function getComponent(uint256 componentId) external view returns (address) {
        return _componentIdToAddress[componentId];
    }

    /**
     * @inheritdoc IGameRegistry
     */
    function getComponentIdFromAddress(
        address componentAddr
    ) external view returns (uint256) {
        return _componentAddressToId[componentAddr];
    }

    /**
     * @inheritdoc IGameRegistry
     */
    function getEntityHasComponent(
        uint256 entity,
        uint256 componentId
    ) external view returns (bool) {
        return _entityToComponents[entity].contains(componentId);
    }

    /**
     * @inheritdoc IGameRegistry
     */
    function batchGetEntitiesHasComponents(
        uint256[] calldata entities,
        uint256[] calldata componentIds
    ) external view returns (bool[] memory) {
        bool[] memory results = new bool[](entities.length);
        for (uint256 i = 0; i < entities.length; i++) {
            results[i] = _entityToComponents[entities[i]].contains(
                componentIds[i]
            );
        }
        return results;
    }

    /**
     * @inheritdoc IGameRegistry
     */
    function getEntityComponents(
        uint256 entity
    ) external view returns (uint256[] memory) {
        return _entityToComponents[entity].values();
    }

    /**
     * @inheritdoc IGameRegistry
     */
    function getEntityComponentCount(
        uint256 entity
    ) external view returns (uint256) {
        return _entityToComponents[entity].length();
    }

    /**
     * @inheritdoc IGameRegistry
     */
    function generateGUIDDeprecated()
        external
        onlyRole(GAME_LOGIC_CONTRACT_ROLE)
        returns (uint256)
    {
        _guidCounter++;
        uint256 guidEntity = EntityLibrary.tokenToEntity(
            address(this),
            _guidCounter
        );
        return guidEntity;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(IERC165, AccessControlUpgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IGameRegistry).interfaceId ||
            interfaceId == type(IERC165).interfaceId ||
            AccessControlUpgradeable.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasAccessRole(
        bytes32 role,
        address account
    ) public view override returns (bool) {
        return AccessControlUpgradeable.hasRole(role, account);
    }

    /**
     * Returns the address of the account the operatorAddress is authorized to
     *
     * @param operatorAddress Address the sending controller
     */
    function getPlayerAccount(
        address operatorAddress
    ) external view returns (address) {
        if (operatorAddress == address(0)) {
            revert InvalidOperatorAddress();
        }

        PlayerAccount memory account = _operatorToPlayerAccount[
            operatorAddress
        ];

        address playerAddress = account.playerAddress;

        if (playerAddress != address(0)) {
            if (
                account.expiration < block.timestamp && account.expiration != 0
            ) {
                revert OperatorExpired();
            }
        } else {
            return operatorAddress;
        }

        return playerAddress;
    }

    /**
     * Called in order to retrieve message to sign to register an oeperator
     *
     * @param player address operator is being registered for
     * @param operator address of operator being registered
     * @param expiration block time for registration (or 0 for infinite)
     * @param blockNumber the message was signed at
     */
    function getOperatorAccountRegistrationMessageToSign(
        address player,
        address operator,
        uint256 expiration,
        uint256 blockNumber
    ) public pure returns (bytes memory) {
        return
            abi.encodePacked(
                "Authorize operator account ",
                Strings.toHexString(uint256(uint160(operator)), 20),
                " to perform gameplay actions on behalf of player account ",
                Strings.toHexString(uint256(uint160(player)), 20),
                " with expiration ",
                Strings.toString(expiration),
                " signed at block ",
                Strings.toString(blockNumber)
            );
    }

    /**
     * Called by an Operator Address with a signature from a Player Address authorizing it until a given expiration time
     *
     * @param signature from signer/player address authorizing operator until expiration time
     * @param player address of player being registered
     * @param operator address of operator being registered
     * @param expiration block time for registration (or 0 for infinite)
     * @param blockNumber the message was signed at
     */
    function registerOperator(
        bytes calldata signature,
        address player,
        address operator,
        uint256 expiration,
        uint256 blockNumber
    ) external whenNotPaused {
        if (_msgSender() != operator) {
            revert InvalidCaller();
        }
        if (
            (block.timestamp - lastRegisterOperatorTime[player]) <
            REGISTER_OPERATOR_COOLDOWN_LIMIT
        ) {
            revert RegisterOperatorInCooldown();
        }
        if (operator == player || operator == address(0)) {
            revert InvalidOperatorAddress();
        }
        if (expiration < block.timestamp && expiration != 0) {
            revert InvalidExpirationTimestamp();
        }
        // if (blockNumber > block.number) {
        //     revert InvalidBlockNumber();
        // }
        // if (block.number > blockNumber + OPERATOR_MESSAGE_BLOCK_LIMIT) {
        //     revert InvalidExpirationBlockNumber();
        // }

        PlayerAccount memory currentAccount = _operatorToPlayerAccount[
            operator
        ];

        if (
            currentAccount.playerAddress != address(0) &&
            currentAccount.playerAddress != player
        ) {
            revert OperatorAlreadyRegistered();
        }

        bytes memory message = getOperatorAccountRegistrationMessageToSign(
            player,
            operator,
            expiration,
            blockNumber
        );
        bytes32 digest = ECDSA.toEthSignedMessageHash(message);
        address recoveredSigner = ECDSA.recover(digest, signature);

        if (player != recoveredSigner) {
            revert PlayerSignerMismatch(player, recoveredSigner);
        }

        _operatorToPlayerAccount[operator] = PlayerAccount({
            playerAddress: player,
            expiration: expiration
        });

        _playerToOperatorAddresses[player].add(operator);

        // Track cooldown timer
        lastRegisterOperatorTime[player] = block.timestamp;

        emit OperatorRegistered(player, operator, expiration);
    }

    /**
     * Batch set operator accounts for players
     * @param players addresses of players being registered
     * @param operators addresses of operators being registered
     * @param expirations block times for registration (or 0 for infinite)
     */
    function registerOperatorBatch(
        address[] calldata players,
        address[] calldata operators,
        uint256[] calldata expirations
    ) external whenNotPaused onlyRole(MANAGER_ROLE) {
        if (
            players.length != operators.length ||
            players.length != expirations.length
        ) {
            revert InvalidOperatorAddress();
        }

        for (uint256 i = 0; i < players.length; i++) {
            if (operators[i] == players[i] || operators[i] == address(0)) {
                revert InvalidOperatorAddress();
            }
            _operatorToPlayerAccount[operators[i]] = PlayerAccount({
                playerAddress: players[i],
                expiration: expirations[i]
            });
            _playerToOperatorAddresses[players[i]].add(operators[i]);
            // Track cooldown timer
            lastRegisterOperatorTime[players[i]] = block.timestamp;
            emit OperatorRegistered(players[i], operators[i], expirations[i]);
        }
    }

    function deregisterOperatorBatch(
        address[] calldata operators
    ) public whenNotPaused onlyRole(MANAGER_ROLE) {
        for (uint256 i = 0; i < operators.length; i++) {
            address playerAddress = _operatorToPlayerAccount[operators[i]]
                .playerAddress;
            // if (playerAddress == address(0)) {
            //     revert OperatorNotRegistered();
            // }
            delete _operatorToPlayerAccount[operators[i]];
            _playerToOperatorAddresses[playerAddress].remove(operators[i]);
            // if (operatorRemovedFromPlayer != true) {
            //     revert OperatorNotRegistered();
            // }
            emit OperatorDeregistered(operators[i], playerAddress);
        }
    }

    /**
     * Called by an Operator or Player to deregister an Operator account
     *
     * @param operatorToDeregister address of operator to deregister
     */
    function deregisterOperator(address operatorToDeregister) external {
        address playerAddress = _operatorToPlayerAccount[operatorToDeregister]
            .playerAddress;

        if (playerAddress == address(0)) {
            revert OperatorNotRegistered();
        }
        if (
            operatorToDeregister != _msgSender() &&
            playerAddress != _msgSender()
        ) {
            revert InvalidDeregisterCaller();
        }

        delete _operatorToPlayerAccount[operatorToDeregister];

        bool operatorRemovedFromPlayer = _playerToOperatorAddresses[
            playerAddress
        ].remove(operatorToDeregister);

        if (operatorRemovedFromPlayer != true) {
            revert OperatorNotRegistered();
        }

        emit OperatorDeregistered(operatorToDeregister, playerAddress);
    }

    /**
     * Returns an array of registered Operators for a Player address
     *
     * @param player address to retrieve operators for
     */
    function getRegisteredOperators(
        address player
    ) external view returns (address[] memory) {
        return _playerToOperatorAddresses[player].values();
    }

    /// @inheritdoc IERC2771Recipient
    function isTrustedForwarder(
        address forwarder
    ) public view virtual override returns (bool) {
        return hasAccessRole(TRUSTED_FORWARDER_ROLE, forwarder);
    }

    /// @inheritdoc IERC2771Recipient
    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, IERC2771Recipient)
        returns (address ret)
    {
        if (msg.data.length >= 20 && isTrustedForwarder(msg.sender)) {
            assembly {
                ret := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            ret = msg.sender;
        }
    }

    /// @inheritdoc IERC2771Recipient
    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, IERC2771Recipient)
        returns (bytes calldata ret)
    {
        if (msg.data.length >= 20 && isTrustedForwarder(msg.sender)) {
            return msg.data[0:msg.data.length - 20];
        } else {
            return msg.data;
        }
    }

    function _generateGUID() internal returns (uint256) {
        GuidCounterComponent counter = GuidCounterComponent(
            _componentIdToAddress[GUID_COUNTER_COMPONENT_ID]
        );

        // Increment guid counter
        uint256 count = counter.getValue(GUID_PREFIX) + 1;
        counter.setValue(GUID_PREFIX, count);
        return GUIDLibrary.packGuid(GUID_PREFIX, count);
    }

    function _enforceChain(address to) internal view {
        uint256 userToChainId = ChainIdComponent(
            _componentIdToAddress[CHAIN_ID_COMPONENT_ID]
        ).getValue(EntityLibrary.addressToEntity(to));

        if (userToChainId != block.chainid) {
            revert InvalidChain(userToChainId);
        }
    }

    function _validateRequestId(uint256 requestId) internal {
        if (requestIdProcessed[requestId]) {
            revert AlreadyProcessed(requestId);
        }
        requestIdProcessed[requestId] = true;
    }

    function _batchSetComponentData(
        BatchComponentData calldata componentData
    ) internal {
        _batchSetComponentValue(
            componentData.entities,
            componentData.componentIds,
            componentData.data
        );
    }

    function _batchSetComponentValue(
        uint256[] calldata entities,
        uint256[] calldata componentIds,
        bytes[] calldata values
    ) internal {
        if (
            entities.length != values.length ||
            entities.length != componentIds.length
        ) {
            revert InvalidBatchData(entities.length, values.length);
        }

        for (uint256 i = 0; i < entities.length; i++) {
            address componentAddress = _componentIdToAddress[componentIds[i]];
            if (componentAddress == address(0)) {
                revert ComponentNotRegistered(componentAddress);
            }
            IComponent(componentAddress).setBytes(entities[i], values[i]);
        }
    }

    function _batchSetComponentValueWithPublish(
        uint256[] calldata entities,
        uint256[] calldata componentIds,
        bytes[] calldata values
    ) internal {
        if (
            entities.length != values.length ||
            entities.length != componentIds.length
        ) {
            revert InvalidBatchData(entities.length, values.length);
        }

        for (uint256 i = 0; i < entities.length; i++) {
            address componentAddress = _componentIdToAddress[componentIds[i]];
            if (componentAddress == address(0)) {
                revert ComponentNotRegistered(componentAddress);
            }

            uint256 requestId = _generateGUID();
            emit PublishComponentValueSet(
                requestId,
                componentIds[i],
                entities[i],
                block.chainid,
                block.timestamp,
                values[i]
            );
            IComponent(componentAddress).setBytes(entities[i], values[i]);
        }
    }
}
