// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

abstract contract ContractTraits {
    // Add the library methods
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    struct Asset {
        /// @dev Name of the rendered trait
        string traitName;
        /// @dev partial URI to the asset, tokenId is appended
        string uri;
        /// @dev mimeType of the asset
        string mimeType;
        /// @dev width of the asset
        uint16 width;
        /// @dev height of the asset
        uint16 height;
    }

    struct ContractInfo {
        /// @dev All asset trait ids for this contract
        EnumerableSetUpgradeable.UintSet assetSet;
        /// @dev All assets for this contract
        mapping(uint256 => Asset) assets;
    }

    /// @notice Traits for a given contract
    mapping(address => ContractInfo) _contracts;

    /** EXTERNAL **/

    /**
     * Adds a new asset type for a contract
     *
     * @param tokenContract Contract to add asset types for
     * @param asset         Asset to add to the contract
     */
    function _addAsset(address tokenContract, Asset calldata asset) internal {
        ContractInfo storage contractInfo = _contracts[tokenContract];
        uint256 traitId = uint256(keccak256(bytes(asset.traitName)));
        contractInfo.assetSet.add(traitId);
        contractInfo.assets[traitId] = asset;
    }

    /**
     * Removes an asset from a contract
     *
     * @param tokenContract Contract to remove asset from
     * @param traitId       Keccak256 traitId of the asset to remove
     */
    function _removeAsset(address tokenContract, uint256 traitId) internal {
        ContractInfo storage contractInfo = _contracts[tokenContract];
        delete contractInfo.assets[traitId];
        contractInfo.assetSet.remove(traitId);
    }

    /** @return All asset trait ids for the given token contract */
    function getAssetTraitIds(address tokenContract)
        external
        view
        returns (uint256[] memory)
    {
        ContractInfo storage contractInfo = _contracts[tokenContract];
        return contractInfo.assetSet.values();
    }

    /**
     * @param tokenContract Token contract to get asset from
     * @param traitId Id of the asset to retrieve
     * @return Returns the asset with the given id
     */
    function getAsset(address tokenContract, uint256 traitId)
        external
        view
        returns (Asset memory)
    {
        ContractInfo storage contractInfo = _contracts[tokenContract];
        return contractInfo.assets[traitId];
    }
}
