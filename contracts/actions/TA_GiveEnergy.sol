// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {IEnergySystemV3, ID as ENERGY_SYSTEM_ID} from "../energy/IEnergySystem.sol";
import {ITokenAction} from "./ITokenAction.sol";
import {IGameRegistry} from "../core/IGameRegistry.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {ITraitsProvider, ID as TRAITS_PROVIDER_ID} from "../interfaces/ITraitsProvider.sol";
import {GAME_LOGIC_CONTRACT_ROLE, ENERGY_PROVIDED_TRAIT_ID} from "../Constants.sol";
import "../GameRegistryConsumerUpgradeable.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.tagiveenergy"));

/**
 * ITokenAction that gives the user some energy
 */
contract TA_GiveEnergy is ITokenAction, GameRegistryConsumerUpgradeable {
    /** ERRORS **/
    /// @notice Only owner can perform action
    error NotOwner();

    /** SETUP **/

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * @inheritdoc ITokenAction
     */
    function isInitDataValid(bytes memory) external pure returns (bool) {
        return true;
    }

    /** EXTERNAL **/

    /**
     * @inheritdoc ITokenAction
     */
    function performGameItemAction(
        address account,
        address tokenContract,
        uint256 tokenId,
        uint256 amount,
        bytes memory,
        bytes memory runtimeData
    ) external override onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        (address targetTokenAddress, uint256 targetTokenId) = abi.decode(
            runtimeData,
            (address, uint256)
        );

        // Verify account owns the given NFT
        if (IERC721(targetTokenAddress).ownerOf(targetTokenId) != account) {
            revert NotOwner();
        }

        ITraitsProvider traitsProvider = ITraitsProvider(
            _getSystem(TRAITS_PROVIDER_ID)
        );
        uint256 energyAmount = traitsProvider.getTraitUint256(
            tokenContract,
            tokenId,
            ENERGY_PROVIDED_TRAIT_ID
        );

        IEnergySystemV3 energySystem = IEnergySystemV3(
            _getSystem(ENERGY_SYSTEM_ID)
        );
        energySystem.giveEnergy(
            EntityLibrary.addressToEntity(account),
            energyAmount * amount
        );
    }
}
