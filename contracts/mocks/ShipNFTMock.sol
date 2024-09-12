// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

import "../tokens/shipnft/ShipNFT.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {ITraitsConsumer} from "../interfaces/ITraitsConsumer.sol";
import {IGameNFTV2Upgradeable} from "../tokens/gamenft/IGameNFTV2Upgradeable.sol";
import {MintCounterComponent, ID as MINT_COUNTER_COMPONENT_ID} from "../generated/components/MintCounterComponent.sol";

/** @title Ship NFT Mock for testing */
contract ShipNFTMock is ShipNFT {
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

    function getEntity(uint256 tokenId) external view returns (uint256) {
        return EntityLibrary.tokenToEntity(address(this), tokenId);
    }

    function currentShipId() external view returns (uint256) {
        return MintCounterComponent(
            _gameRegistry.getComponent(MINT_COUNTER_COMPONENT_ID)
        ).getValue(ID);
    }
}
