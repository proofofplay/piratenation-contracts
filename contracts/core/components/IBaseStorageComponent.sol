// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {TypesLibrary} from "../TypesLibrary.sol";

interface IBaseStorageComponent {
    /**
     * Emit the raw bytes value set for this component
     * @param entity Entity to set value for
     * @param value Bytes encoded value for this comoonent
     */
    function emitSetBytes(uint256 entity, bytes memory value) external;

    /**
     * Batch emit the raw bytes values set for this component
     * @param entities Array of entities to set values for.
     * @param values Array of values to set for a given entity.
     */
    function emitBatchSetBytes(
        uint256[] calldata entities,
        bytes[] memory values
    ) external;

    /**
     * Emit when removing an entity from this component
     * @param entity Entity to remove
     */
    function emitRemoveBytes(uint256 entity) external;

    /**
     * Batch emit when removing entities from this component
     * @param entities Array of entities to remove from this component.
     */
    function emitBatchRemoveBytes(uint256[] calldata entities) external;

    /** Return the keys and value types of the schema of this component. */
    function getSchema()
        external
        pure
        returns (
            string[] memory keys,
            TypesLibrary.SchemaValue[] memory values
        );
}
