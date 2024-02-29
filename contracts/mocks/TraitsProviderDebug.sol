// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "../GameRegistryConsumerUpgradeable.sol";

/** @title TraitsProvider debug contract that proxies calls to the traits provider for use on testnets */
contract TraitsProviderDebug is GameRegistryConsumerUpgradeable {
    /**
     * @dev Permissionless call
     */
    function setTraitInt256(
        address tokenContract,
        uint256 tokenId,
        uint256 traitId,
        int256 value
    ) external {
        _traitsProvider().setTraitInt256(
            tokenContract,
            tokenId,
            traitId,
            value
        );
    }

    /**
     * @dev Permissionless call
     */
    function setTraitUint256(
        address tokenContract,
        uint256 tokenId,
        uint256 traitId,
        uint256 value
    ) external {
        _traitsProvider().setTraitUint256(
            tokenContract,
            tokenId,
            traitId,
            value
        );
    }

    /**
     * @dev Permissionless call
     */
    function setTraitString(
        address tokenContract,
        uint256 tokenId,
        uint256 traitId,
        string memory value
    ) external {
        _traitsProvider().setTraitString(
            tokenContract,
            tokenId,
            traitId,
            value
        );
    }

    /**
     * @dev Permissionless call
     */
    function setTraitBool(
        address tokenContract,
        uint256 tokenId,
        uint256 traitId,
        bool value
    ) external {
        _traitsProvider().setTraitBool(tokenContract, tokenId, traitId, value);
    }
}
