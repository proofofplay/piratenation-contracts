// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {CURRENT_HEALTH_TRAIT_ID} from "../../Constants.sol";
import {EntityLibrary} from "../../core/EntityLibrary.sol";

import "../../combat/BossSpawn.sol";

contract BossSpawnMock is BossSpawn {
    error InvalidBossEnity(uint256 entityId);

    function setHealth(uint256 entityId, uint256 health) external {
        (address contractAddress, uint256 tokenId) = EntityLibrary
            .entityToToken(entityId);

        if (contractAddress != address(this)) {
            revert InvalidBossEnity(entityId);
        }

        _traitsProvider().setTraitUint256(
            address(this),
            tokenId,
            CURRENT_HEALTH_TRAIT_ID,
            health
        );
    }

    function getEntity(uint256 tokenId) external view returns (uint256) {
        return EntityLibrary.tokenToEntity(address(this), tokenId);
    }
}
