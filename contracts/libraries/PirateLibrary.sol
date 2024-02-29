// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import {ITraitsProvider, ID as TRAITS_PROVIDER_ID} from "../interfaces/ITraitsProvider.sol";
import {IGameRegistry} from "../core/IGameRegistry.sol";
import {GAME_NFT_CONTRACT_ROLE, IS_PIRATE_TRAIT_ID} from "../Constants.sol";

/**
 * Common helper functions for dealing with Pirates (Gen0 and Gen1)
 */
library PirateLibrary {
    /**
     * @dev Checks if the NFT is a pirate NFT
     * @param gameRegistry GameRegistry contract
     * @param traitsProvider TraitsProvider contract
     * @param tokenContract token contract address
     * @param tokenId token id
     */
    function isPirateNFT(
        IGameRegistry gameRegistry,
        ITraitsProvider traitsProvider,
        address tokenContract,
        uint256 tokenId
    ) internal view returns (bool) {
        return (gameRegistry.hasAccessRole(
            GAME_NFT_CONTRACT_ROLE,
            tokenContract
        ) &&
            traitsProvider.hasTrait(
                tokenContract,
                tokenId,
                IS_PIRATE_TRAIT_ID
            ));
    }
}
