// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import "../tokens/achievementnft/AchievementNFT.sol";
import {ITraitsConsumer} from "../interfaces/ITraitsConsumer.sol";
import {IGameNFTV2Upgradeable} from "../tokens/gamenft/IGameNFTV2Upgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

/** @title Achievement NFT Mock for testing */
contract AchievementNFTMock is AchievementNFT {
    function GAMENFT_INTERFACEID() external pure returns (bytes4) {
        return type(IGameNFTV2Upgradeable).interfaceId;
    }

    function ITRAITSCONSUMER_INTERFACEID() external pure returns (bytes4) {
        return type(ITraitsConsumer).interfaceId;
    }

    function burnForTests(uint256 tokenId) external {
        _burn(tokenId);
    }

    function mintForTests(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }

    function mintWithoutTraits(address to, uint256 tokenId) external {
        ERC721Upgradeable._safeMint(to, tokenId);
    }
}
