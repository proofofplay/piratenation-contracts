// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import "../trade/AccountXpSystem.sol";

/** @title Account Xp System Mock for testing */
contract AccountXpSystemMock is AccountXpSystem {
    function grantAccountSkillXpForTests(
        uint256 entity,
        uint256 amount,
        uint256 skillEntity
    ) external {
        _grantAccountSkillXp(entity, amount, skillEntity);
    }
}
