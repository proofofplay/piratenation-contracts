// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

// @notice Interface for Polygon bridgable NFTs on L2-chain
interface IERC721BridgableChild is IERC721Enumerable {
    /**
     * @notice called when token is deposited on root chain
     * @dev Should be callable only by ChildChainManager and call _deposit
     *
     * @param to            Address being deposited to
     * @param depositData   ABI encoded ids being deposited
     */
    function deposit(address to, bytes calldata depositData) external;

    /** @return Whether or not the given tokenId has been minted/exists */
    function exists(uint256 tokenId) external view returns (bool);
}
