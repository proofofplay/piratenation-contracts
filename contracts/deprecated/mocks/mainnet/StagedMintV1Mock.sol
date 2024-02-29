// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

/// ============ Imports ============

import "../../mainnet/StagedMintV1.sol"; // Extend main staged mint contract

/// @title an extended staged mint contract that makes internal functions public for testing
contract StagedMintV1Mock is StagedMintV1 {
    // call parent constructor
    constructor(
        uint256 _PREMINT_COST,
        uint256 _MINT_COST,
        uint256 _AVAILABLE_SUPPLY,
        uint256 _MAX_PER_ADDRESS,
        address _NFT_CONTRACT_ADDRESS
    )
        StagedMintV1(
            _PREMINT_COST,
            _MINT_COST,
            _AVAILABLE_SUPPLY,
            _MAX_PER_ADDRESS,
            _NFT_CONTRACT_ADDRESS
        )
    {}
}
