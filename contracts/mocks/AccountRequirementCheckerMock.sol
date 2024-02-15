// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../requirements/IAccountRequirementChecker.sol";
import "../GameRegistryConsumer.sol";

/** @title Pirate NFT Mock for testing */
contract AccountRequirementCheckerMock {
    // constructor() {
    //     // Do nothing
    // }

    /** Whether or not the given bytes array is valid */
    function isDataValid(bytes memory data) external pure returns (bool) {
        if (data.length != 0) return true;
        return false;
    }

    /**
     * Whether or not the given account meets the requirement
     *
     * @param account Account to check
     * @param data    ABI encoded parameter data to perform the check
     */
    function meetsRequirement(address account, bytes memory data)
        external
        pure
        returns (bool)
    {
        if (account != address(0) && data.length != 0) return true;
        return false;
    }
}
