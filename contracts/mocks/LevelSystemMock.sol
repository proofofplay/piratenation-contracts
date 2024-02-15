// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

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

        // Apply XP modifier for captain
        (address captainTokenContract, uint256 captainTokenId) = captainSystem
            .getCaptainNFT(owner);

        IGameGlobals gameGlobals = IGameGlobals(_getSystem(GAME_GLOBALS_ID));

        // If NFT is the captain, grant bonus XP
        if (
            captainTokenContract == tokenContract && captainTokenId == tokenId
        ) {
            amount =
                amount +
                (amount * gameGlobals.getUint256(CAPTAIN_XP_BONUS_PERCENT_ID)) /
                PERCENTAGE_RANGE;
        }

        ITraitsProvider traitsProvider = ITraitsProvider(
            _getSystem(TRAITS_PROVIDER_ID)
        );

        // Cap XP
        uint256 maxXp = gameGlobals.getUint256(MAX_XP_ID);
        uint256 currentXp = traitsProvider.getTraitUint256(
            tokenContract,
            tokenId,
            XP_TRAIT_ID
        );
        amount = Math.min(maxXp - currentXp, amount);
        if (amount > 0) {
            traitsProvider.incrementTrait(
                tokenContract,
                tokenId,
                XP_TRAIT_ID,
                amount
            );
        }
    }
}
