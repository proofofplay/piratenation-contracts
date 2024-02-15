// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

uint256 constant ID = uint256(keccak256("game.piratenation.captainsystem"));

interface ICaptainSystem {
    /**
     * Sets the current captain NFT for the player
     *
     * @param tokenContract Address of the captain NFT
     * @param tokenId       Id of the captain NFT token
     */
    function setCaptainNFT(address tokenContract, uint256 tokenId) external;

    /**
     * @return tokenContract Token contract for the captain NFT
     * @return tokenId       Token id for the captain NFT
     */
    function getCaptainNFT(address account)
        external
        view
        returns (address tokenContract, uint256 tokenId);
}
