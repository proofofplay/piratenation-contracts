// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol"; // OZ: ERC165 interface

contract ERC165Mock is IERC165 {
    function supportsInterface(bytes4 interfaceID)
        external
        pure
        override(IERC165)
        returns (bool)
    {
        return interfaceID == type(IERC165).interfaceId;
    }
}
