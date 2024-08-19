// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

interface IMultichain721 {
    /**
     * A contract that implements this interface is capable of receiving Multichain721 transfers
     * This functiog the item
     * @param tokenId id of the items to mintn should mint the item appropriately
     * This will be called AFTER generic checks have been made such as
     * - Validating to address is on this chain
     * - Ensuring replay attacks are prevented
     * @param to address of user recievin
     */
    function receivedMultichain721Transfer(
        address to,
        uint256 tokenId
    ) external;
}
