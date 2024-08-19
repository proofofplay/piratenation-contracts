// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// @title Interface the game's ACL / Management Layer
interface IGameRegistry is IERC165 {
    /**
     * @dev Returns `true` if `account` has been granted `role`.
     * @param role The role to query
     * @param account The address to query
     */
    function hasAccessRole(
        bytes32 role,
        address account
    ) external view returns (bool);

    /**
     * @return Whether or not the registry is paused
     */
    function paused() external view returns (bool);

    /**
     * Registers a system by id
     *
     * @param systemId          Id of the system
     * @param systemAddress     Address of the system contract
     */
    function registerSystem(uint256 systemId, address systemAddress) external;

    /**
     * @param systemId Id of the system
     * @return System based on an id
     */
    function getSystem(uint256 systemId) external view returns (address);

    /**
     * Registers a component using an id and contract address
     * @param componentId Id of the component to register
     * @param componentAddress Address of the component contract
     */
    function registerComponent(
        uint256 componentId,
        address componentAddress
    ) external;

    /**
     * @param componentId Id of the component
     * @return A component's contract address given its ID
     */
    function getComponent(uint256 componentId) external view returns (address);

    /**
     * @param componentAddr Address of the component contract
     * @return A component's id given its contract address
     */
    function getComponentIdFromAddress(
        address componentAddr
    ) external view returns (uint256);

    /**
     * @param entity        Entity to check
     * @param componentId   Component to check
     * @return Boolean indicating if entity belongs to component
     */
    function getEntityHasComponent(
        uint256 entity,
        uint256 componentId
    ) external view returns (bool);

    /**
     * @return Boolean array indicating if entity belongs to component
     * @param entities      Entities to check
     * @param componentIds   Components to check
     */
    function batchGetEntitiesHasComponents(
        uint256[] calldata entities,
        uint256[] calldata componentIds
    ) external view returns (bool[] memory);

    /**
     * Sets multiple component values at once
     * @param entities Entities to set values for
     * @param componentIds Component to set value on
     * @param values Values to set
     */
    function batchSetComponentValue(
        uint256[] calldata entities,
        uint256[] calldata componentIds,
        bytes[] calldata values
    ) external;

    /**
     * Sets multiple component values at once and emits a publish event (for cross-chain)
     * @param entities Entities to set values for
     * @param componentIds Component to set value on
     * @param values Values to set
     */
    function batchPublishSetComponentValue(
        uint256[] calldata entities,
        uint256[] calldata componentIds,
        bytes[] calldata values
    ) external returns (uint256 requestId);

    /**
     * @param componentId Id of the component
     * @return Entire array of components belonging an entity
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function getEntityComponents(
        uint256 componentId
    ) external view returns (uint256[] memory);

    /**
     * @param componentId Id of the component
     * @return Number of components belonging to an entity
     */
    function getEntityComponentCount(
        uint256 componentId
    ) external view returns (uint256);

    /**
     * Gets multiple component values at once
     * @param entities Entities to get values for
     * @param componentIds Component to get value from
     */
    function batchGetComponentValues(
        uint256[] calldata entities,
        uint256[] calldata componentIds
    ) external view returns (bytes[] memory values);

    /**
     * Register a component value update.
     * Emits the `ComponentValueSet` event for clients to reconstruct the state.
     * @param entity Entity to update
     * @param data Data to update
     */
    function registerComponentValueSet(
        uint256 entity,
        bytes calldata data
    ) external;

    /**
     * Emit a component value update across chains.
     * Emits the `PublishComponentValueSet` event for cross-chain clients to reconstruct the state.
     * @param entity Entity to update
     * @param data Data to update
     */
    function publishComponentValueSet(
        uint256 componentId,
        uint256 entity,
        bytes calldata data
    ) external returns (uint256);

    /**
     * Register a component batch value update.
     * Emits the `ComponentBatchValueSet` event for clients to reconstruct the state.
     * @param entities Entities to update
     * @param data Data to update
     */
    function batchRegisterComponentValueSet(
        uint256[] calldata entities,
        bytes[] calldata data
    ) external;

    /**
     * Emit a component batch value update across chains.
     * Emits the `PublishComponentBatchValueSet` event for cross-chain clients to reconstruct the state.
     * @param entities Entities to update
     * @param data Data to update
     */
    function batchPublishComponentValueSet(
        uint256 componentId,
        uint256[] calldata entities,
        bytes[] calldata data
    ) external returns (uint256);

    /**
     * Register a component value removal.
     * Emits the `ComponentValueRemoved` event for clients to reconstruct the state.
     */
    function registerComponentValueRemoved(uint256 entity) external;

    /**
     * Emit a component value removal across chains.
     * Emits the `PublishComponentValueRemoved` event for cross-chain clients to reconstruct the state.
     */
    // TODO: Reenable when we're ready to support cross-chain removal
    // function publishComponentValueRemoved(
    //     uint256 componentId,
    //     uint256 entity
    // ) external returns (uint256);

    /**
     * Register a component batch value removal.
     * Emits the `ComponentBatchValueRemoved` event for clients to reconstruct the state.
     * @param entities Entities to update
     */
    function batchRegisterComponentValueRemoved(
        uint256[] calldata entities
    ) external;

    /**
     * Emit a component batch value removal across chains.
     * Emits the `PublishComponentBatchValueRemoved` event for cross-chain clients to reconstruct the state.
     * @param entities Entities to update
     */
    // TODO: Reenable when we're ready to support cross-chain removal
    // function batchPublishComponentValueRemoved(
    //     uint256 componentId,
    //     uint256[] calldata entities
    // ) external returns (uint256);

    /**
     * DEPRECATED: Generate a new general-purpose entity GUID
     */
    function generateGUIDDeprecated() external returns (uint256);

    /**
     *
     * @param operatorAddress   Address of the Operator account
     * @return Authorized Player account for an address
     */
    function getPlayerAccount(
        address operatorAddress
    ) external view returns (address);

    /**
     * @notice Sends a transfer to another chain in the multichain
     * @param systemId Id of the 1155 System (Must implement IMultichain1155)
     * @param from From address of the user sending the token
     * @param to To address of the user receiving the token
     * @param toChainId Chain ID of the receiving chain
     * @param id Array of token IDs to send
     * @param amount Array of token amounts to send
     */
    function sendMultichain1155TransferSingle(
        uint256 systemId,
        address from,
        address to,
        uint256 toChainId,
        uint256 id,
        uint256 amount
    ) external;

    /**
     * @notice Sends a transfer to another chain in the multichain
     * @param systemId Id of the 1155 System (Must implement IMultichain1155)
     * @param from From address of the user sending the token
     * @param to To address of the user receiving the token
     * @param toChainId Chain ID of the receiving chain
     * @param ids Array of token IDs to send
     * @param amounts Array of token amounts to send
     */
    function sendMultichain1155TransferBatch(
        uint256 systemId,
        address from,
        address to,
        uint256 toChainId,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external;

    /**
     * @notice Sends a transfer to another chain in the multichain
     * @param systemId Id of the 1155 System (Must implement Multichain721)
     * @param from From address of the user sending the token
     * @param to To address of the user receiving the token
     * @param tokenId the tokenId being transferred
     * @param toChainId Chain ID of the receiving chain
     */
    function sendMultichain721Transfer(
        uint256 systemId,
        address from,
        address to,
        uint256 tokenId,
        uint256 toChainId
    ) external;
}
