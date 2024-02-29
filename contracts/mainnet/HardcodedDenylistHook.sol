// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "./IBeforeTokenTransferHandler.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * A before transfer hook that blocks transfers based on a hardcoded list of contract addresses.
 */
contract HardcodedDenylistHook is IBeforeTokenTransferHandler, Ownable {
    /// @notice The list of operators to bar from facilitating NFT sales.
    address[] private denylistedOperators = [
        0xf42aa99F011A1fA7CDA90E5E98b277E306BcA83e, //looks rare
        0xFED24eC7E22f573c2e08AEF55aA6797Ca2b3A051, //looks rare
        0xD42638863462d2F21bb7D4275d7637eE5d5541eB, //sudo
        0x08CE97807A81896E85841d74FB7E7B065ab3ef05, //sudo
        0x92de3a1511EF22AbCf3526c302159882a4755B22, //sudo
        0xCd80C916B1194beB48aBF007D0b79a7238436D56, //sudo
        0xb16c1342E617A5B6E4b631EB114483FDB289c0A4, //sudo
        0x0fc584529a2AEfA997697FAfAcbA5831faC0c22d, //nftx
        0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC, //opensea seaport 1.5
        0x00000000000001ad428e4906aE43D8F9852d0dD6, //opensea seaport 1.4
        0x1E0049783F008A0085193E00003D00cd54003c71 //opensea conduit
    ];

    /** ERRORS **/
    error OperatorNotAllowed(address operator);

    /**
     * Get the addresses of the operators this contract is blocking.
     *
     * @return address[] The array of addresses this contract is blocking.
     */
    function getDenylistOperators() external view returns (address[] memory) {
        return denylistedOperators;
    }

    /**
     * Add an address to the denylist.
     *
     * @param addr The address to add to the denylist.
     */
    function addDenylistedAddress(address addr) external onlyOwner {
        denylistedOperators.push(addr);
    }

    /**
     * Remove an address from the denylist.
     *
     * @param addr The address to remove from the denylist.
     */
    function removeDenylistedAddress(address addr) external onlyOwner {
        for (uint256 i = 0; i < denylistedOperators.length; i++) {
            if (denylistedOperators[i] == addr) {
                delete denylistedOperators[i];
                break;
            }
        }
    }

    /**
     * Handles before token transfer events from a ERC721 contract.
     */
    function beforeTokenTransfer(
        address tokenContract,
        address operator,
        address from,
        address to,
        uint256 tokenId
    ) external view {
        beforeTokenTransfer(tokenContract, operator, from, to, tokenId, 1);
    }

    /**
     * Handles before token transfer events from a ERC721 contract.
     */
    function beforeTokenTransfer(
        address,
        address operator,
        address,
        address,
        uint256,
        uint256
    ) public view {
        uint256 addressListLength = denylistedOperators.length;
        for (uint256 i = 0; i < addressListLength; i++) {
            if (operator == address(denylistedOperators[i])) {
                revert OperatorNotAllowed(operator);
            }
        }
    }
}
