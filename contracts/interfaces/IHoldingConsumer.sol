// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

interface IHoldingConsumer {
    /**
     * @param account Account to check hold time of
     * @param tokenId Id of the token
     * @return The time in seconds a given account has held a token
     */
    function getTimeHeld(
        address account,
        uint256 tokenId
    ) external view returns (uint32);

    /**
     * @param tokenId Id of the token
     * @return The time in seconds a given account has held the token
     */
    function getLastTransfer(uint256 tokenId) external view returns (uint32);
}
