// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import {TransformAccountDataComponent, Layout as TransformAccountDataComponentLayout, ID as TRANSFORM_ACCOUNT_DATA_COMPONENT_ID} from "../generated/components/TransformAccountDataComponent.sol";
import {IGameRegistry} from "../core/IGameRegistry.sol";
import {TransformInputComponent, ID as TRANSFORM_INPUT_COMPONENT_ID, Layout as TransformInputComponentStruct, Layout as TransformInputComponentLayout} from "../generated/components/TransformInputComponent.sol";
import {VipTransformInputComponent, ID as VIP_TRANSFORM_INPUT_COMPONENT_ID, Layout as VipTransformInputComponentLayout} from "../generated/components/VipTransformInputComponent.sol";
import {ISubscriptionSystem, ID as SUBSCRIPTION_SYSTEM_ID, VIP_SUBSCRIPTION_TYPE} from "../subscription/ISubscriptionSystem.sol";

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

    /** @return Get the transform inputs for an account */
    function getTransformInputsForAccount(
        IGameRegistry gameRegistry,
        address account,
        uint256 transformEntity
    ) internal view returns (TransformInputComponentLayout memory) {
        if (
            ISubscriptionSystem(gameRegistry.getSystem(SUBSCRIPTION_SYSTEM_ID))
                .checkHasActiveSubscription(VIP_SUBSCRIPTION_TYPE, account)
        ) {
            VipTransformInputComponentLayout
                memory vipTransformInputs = VipTransformInputComponent(
                    gameRegistry.getComponent(VIP_TRANSFORM_INPUT_COMPONENT_ID)
                ).getLayoutValue(transformEntity);

            if (vipTransformInputs.inputEntity.length > 0) {
                return
                    TransformInputComponentLayout({
                        inputType: vipTransformInputs.inputType,
                        inputEntity: vipTransformInputs.inputEntity,
                        amount: vipTransformInputs.amount
                    });
            }
        }

        return
            TransformInputComponent(
                gameRegistry.getComponent(TRANSFORM_INPUT_COMPONENT_ID)
            ).getLayoutValue(transformEntity);
    }
}
