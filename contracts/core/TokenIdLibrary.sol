// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

error ChainIdOverflow();

// Apex Chain ID
uint256 constant APEX_CHAIN_ID = 70700;

// Barret Chain ID
uint256 constant BARRET_CHAIN_ID = 70800;

// Cid Chain ID
uint256 constant CID_CHAIN_ID = 70804;

// Local Chain ID
uint256 constant LOCAL_CHAIN_ID = 31337;

library TokenIdLibrary {
    /** @return finalTokenId uint96 packed from tokenId and chainId */
    function generateTokenId(
        uint256 _tokenId
    ) internal view returns (uint96 finalTokenId) {
        uint64 tokenId = uint64(_tokenId);
        uint256 chainId = block.chainid;
        if (chainId > type(uint32).max) {
            revert ChainIdOverflow();
        }
        if (
            chainId == APEX_CHAIN_ID ||
            chainId == BARRET_CHAIN_ID ||
            chainId == CID_CHAIN_ID ||
            chainId == LOCAL_CHAIN_ID
        ) {
            // If it's the apex, barret, or cid chain, keep the original tokenId
            finalTokenId = uint96(tokenId);
        } else {
            // Shift chainId by 64 bits left and combine it with tokenId
            finalTokenId = uint96((chainId << 64) | tokenId);
        }
    }
}
