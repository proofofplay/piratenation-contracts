// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "./GameRegistryLibrary.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ITraitsProvider} from "../interfaces/ITraitsConsumer.sol";
import {IGameItems} from "../tokens/gameitems/IGameItems.sol";
import {IGameCurrency} from "../tokens/IGameCurrency.sol";
import {LEVEL_TRAIT_ID} from "../Constants.sol";

/** @title Common helper functions for the game **/
library GameHelperLibrary {
    /** @return level for the given token */
    function _levelForPirate(
        ITraitsProvider traitsProvider,
        address tokenContract,
        uint256 tokenId
    ) internal view returns (uint256) {
        if (traitsProvider.hasTrait(tokenContract, tokenId, LEVEL_TRAIT_ID)) {
            return
                traitsProvider.getTraitUint256(
                    tokenContract,
                    tokenId,
                    LEVEL_TRAIT_ID
                );
        } else {
            return 0;
        }
    }

    /**
     * verify is an account owns an input
     *
     * @param input the quest input to verify
     * @param account the owner's address
     *
     */
    function _verifyInputOwnership(
        GameRegistryLibrary.TokenPointer memory input,
        address account
    ) internal view {
        if (input.tokenType == GameRegistryLibrary.TokenType.ERC20) {
            require(
                IGameCurrency(input.tokenContract).balanceOf(account) >=
                    input.amount,
                "INSUFFICIENT_FUNDS"
            );
        } else if (input.tokenType == GameRegistryLibrary.TokenType.ERC721) {
            require(
                IERC721(input.tokenContract).ownerOf(input.tokenId) == account,
                "NOT_OWNER"
            );
        } else if (input.tokenType == GameRegistryLibrary.TokenType.ERC1155) {
            require(
                IGameItems(input.tokenContract).balanceOf(
                    account,
                    input.tokenId
                ) >= input.amount,
                "NOT_OWNER"
            );
        }
    }
}
