// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import {PirateNFTL2} from "../tokens/PirateNFTL2.sol";
import {IGameNFTV2Upgradeable} from "../tokens/gamenft/IGameNFTV2Upgradeable.sol";
import {ITraitsConsumer} from "../interfaces/ITraitsConsumer.sol";

/** @title PirateNFTL2 Mock for testing */
contract PirateNFTL2Mock is PirateNFTL2 {
    uint256 counter;

    function GAMENFT_INTERFACEID() external pure returns (bytes4) {
        return type(IGameNFTV2Upgradeable).interfaceId;
    }

    function ITRAITSCONSUMER_INTERFACEID() external pure returns (bytes4) {
        return type(ITraitsConsumer).interfaceId;
    }

    function mintForTests(address to, uint256 tokenId) external {
        if (counter == 0) {
            counter = 1;
        }
        _safeMint(to, tokenId);
        counter = tokenId + 1;
    }

    function burnForTests(uint256 tokenId) external {
        if (counter == 0) {
            counter = 1;
        }
        _burn(tokenId);
    }

    function mintWithoutTraits(address to, uint256 tokenId) external {
        if (counter == 0) {
            counter = 1;
        }
        ERC721Upgradeable._safeMint(to, tokenId);
        counter = tokenId + 1;
    }

    function mintBatch(address to, uint8 amount) external {
        if (counter == 0) {
            counter = 1;
        }
        for (uint8 i; i < amount; ++i) {
            _safeMint(to, counter);
            counter += 1;
        }
    }
}
