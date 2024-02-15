// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import {TransformAccountDataComponent, Layout as TransformAccountDataComponentLayout, ID as TRANSFORM_ACCOUNT_DATA_COMPONENT_ID} from "../generated/components/TransformAccountDataComponent.sol";
import {IGameRegistry} from "../core/IGameRegistry.sol";

library TransformLibrary {
    /** @return Unique entity id for an account and transform entity */
    function _getAccountTransformDataEntity(
        address account,
        uint256 transformEntity
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(account, transformEntity)));
    }

    /** @return Get the account transform data from the account and transform entity */
    function getAccountTransformData(
        IGameRegistry _gameRegistry,
        address account,
        uint256 transformEntity
    ) internal view returns (TransformAccountDataComponentLayout memory) {
        // Get the transform definition from the transform entity
        TransformAccountDataComponent transformAccountDataComponent = TransformAccountDataComponent(
                _gameRegistry.getComponent(TRANSFORM_ACCOUNT_DATA_COMPONENT_ID)
            );
        return
            transformAccountDataComponent.getLayoutValue(
                _getAccountTransformDataEntity(account, transformEntity)
            );
    }
}
