// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "../traits/TraitsProvider.sol";

/** @title Traits Provider Mock for testing */
contract TraitsProviderMock is TraitsProvider {
    bytes4 public constant TRAITSPROVIDER_INTERFACEID =
        type(ITraitsProvider).interfaceId;
}
