// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {MANAGER_ROLE} from "../../Constants.sol";

abstract contract ERC721ContractURIUpgradeable {
    /// @notice Current metadata URI for the contract
    string private _contractURI;

    /// @notice Emitted when contractURI has changed
    event ContractURIUpdated(string uri);

    /**
     * Sets the current contractURI for the contract
     *
     * @param _uri New contract URI
     */
    function setContractURI(string calldata _uri) public {
        _checkRole(MANAGER_ROLE, _msgSender());
        _contractURI = _uri;
        emit ContractURIUpdated(_uri);
    }

    /**
     * @return Contract metadata URI for the NFT contract, used by NFT marketplaces to display collection inf
     */
    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    /**
     * This will be included by GameRegistryConsumer which checks the gameRegistry for various roles
     * @param role The role to check
     * @param account The account to check
     */
    function _checkRole(bytes32 role, address account) internal view virtual;

    /**
     * This will be included by GameRegistryConsumer which checks the gameRegistry for various roles
     */
    function _msgSender() internal view virtual returns (address);

    uint256[49] private __gap;
}
