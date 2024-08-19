// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

bytes32 constant TRUSTED_MIRROR_ROLE = keccak256("TRUSTED_MIRROR_ROLE");
bytes32 constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

/**
 * @title ERC721MirroredL2Upgradeable
 * An extension to ERC721 that allows for ownership to be mirrored from L1 to L2
 * This is meant to be used by contracts using GameRegistryConsumer, but any system can implement _checkRole
 * This is meant to be used with either an Oracle on L1, or an L1 to L2 handler
 */
abstract contract ERC721MirroredL2Upgradeable is ERC721Upgradeable {
    bool private _isCheckingRole;

    error Soulbound();

    function __ERC721MirroredL2_init(
        string memory name_,
        string memory symbol_
    ) internal {
        _isCheckingRole = true;
        __ERC721_init(name_, symbol_);
    }

    /**
     * @param isCheckingRole Whether to check the TRUSTED_MIRROR_ROLE when transferring tokens
     */
    function setIsCheckingRole(bool isCheckingRole) external {
        _checkRole(MANAGER_ROLE, _msgSender());
        _isCheckingRole = isCheckingRole;
    }

    /**
     * Called by the Oracle or L1 to L2 handler, transfers the ownership.
     * Always checks the role regardless of wether the beforeTransferHook does
     * @param from The address to transfer from
     * @param to The address to transfer to
     * @param tokenId The token id to transfer
     */
    function mirrorOwnership(
        address from,
        address to,
        uint256 tokenId
    ) external {
        _checkRole(TRUSTED_MIRROR_ROLE, _msgSender());

       _mirrorOwnership(from, to, tokenId);
    }

    function _mirrorOwnership(
        address from,
        address to,
        uint256 tokenId
    ) internal {
        if (from == address(0x0)) {
            _mint(to, tokenId);
        } else if (to == address(0x0)) {
            _burn(tokenId);
        } else {
            _transfer(from, to, tokenId);
        }
    }

    /**
     * This will be included by GameRegistryConsumer which checks the gameRegistry for various roles
     * @param role The role to check
     * @param account The account to check
     */
    function _checkRole(bytes32 role, address account) internal virtual;

    /**
     * @inheritdoc ERC721Upgradeable
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override(ERC721Upgradeable) {
        if (_isCheckingRole) {
            _checkRole(TRUSTED_MIRROR_ROLE, _msgSender());
        }

        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    uint256[49] private __gap;
}
