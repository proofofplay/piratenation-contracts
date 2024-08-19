// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

interface IMultichain1155 {
    /**
     * A contract that implements this interface is capable of receiving Multichain1155 transfers
     * This function should mint the item appropriately
     * This will be called AFTER generic checks have been made such as
     * - Validating to address is on this chain
     * - Ensuring replay attacks are prevented
     * @param to address of user recieving the item
     * @param id ids of the items to mint
     * @param amount amount of the items to mint
     */
    function receivedMultichain1155TransferSingle(
        address to,
        uint256 id,
        uint256 amount
    ) external;

    /**
     * A contract that implements this interface is capable of receiving Multichain1155 transfers
     * This function should mint the item appropriately
     * This will be called AFTER generic checks have been made such as
     * - Validating to address is on this chain
     * - Ensuring replay attacks are prevented
     * @param to address of user recieving the item
     * @param ids ids of the items to mint
     * @param amounts amount of the items to mint
     */
    function receivedMultichain1155TransferBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external;
}
