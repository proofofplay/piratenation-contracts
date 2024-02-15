// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {TypesLibrary} from "../TypesLibrary.sol";

interface IGenericComponent {
    /** Return the keys and value types of the schema of this component. */
    function getSchema()
        external
        pure
        returns (
            string[] memory keys,
            TypesLibrary.SchemaValue[] memory values
        );

    /**
     * @param entity Entity to retrieve collecton for
     * @return The raw bytes value for the given entity collection in this component
     */
    function getByteValues(
        uint256 entity
    ) external view returns (bytes[] memory);

    /**
     * Whether or not the entity exists in this component
     * @param entity Entity to check for
     * @return true if the entity exists
     */
    function has(uint256 entity) external view returns (bool);
}
