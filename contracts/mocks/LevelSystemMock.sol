// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import "../level/LevelSystem.sol";

/** @title LevelSystemMock for testing */
contract LevelSystemMock is LevelSystem {
    // Grant xp for tests
    function grantXPForTests(
        address tokenContract,
        uint256 tokenId,
        uint256 amount
    ) external {
        address owner = IERC721(tokenContract).ownerOf(tokenId);

        ICaptainSystem captainSystem = ICaptainSystem(
            _getSystem(CAPTAIN_SYSTEM_ID)
        );

        uint256 entityId = EntityLibrary.tokenToEntity(tokenContract, tokenId);

        Uint256Component uint256Component = Uint256Component(
            _gameRegistry.getComponent(UINT256_COMPONENT_ID)
        );

        // Apply XP modifier for captain
        (address captainTokenContract, uint256 captainTokenId) = captainSystem
            .getCaptainNFT(owner);

        // If NFT is the captain, grant bonus XP
        if (
            captainTokenContract == tokenContract && captainTokenId == tokenId
        ) {
            amount =
                amount +
                (amount *
                    uint256Component.getValue(CAPTAIN_XP_BONUS_PERCENT_ID)) /
                PERCENTAGE_RANGE;
        }

        // Cap XP
        uint256 maxXp = uint256Component.getValue(MAX_XP_ID);
        uint256 currentXp = XpComponent(
            _gameRegistry.getComponent(XP_COMPONENT_ID)
        ).getValue(entityId);

        amount = Math.min(maxXp - currentXp, amount);
        if (amount > 0) {
            XpComponent(_gameRegistry.getComponent(XP_COMPONENT_ID)).setValue(
                entityId,
                currentXp + amount
            );
        }
    }
}
