// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {IAccountRequirementChecker} from "./IAccountRequirementChecker.sol";
import {ITraitsProvider, ID as TRAITS_PROVIDER_ID} from "../interfaces/ITraitsProvider.sol";
import {ICaptainSystem, ID as CAPTAIN_SYSTEM_ID} from "../captain/ICaptainSystem.sol";
import "../libraries/TraitsLibrary.sol";

import "../GameRegistryConsumerUpgradeable.sol";

import {LEVEL_TRAIT_ID} from "../Constants.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.arccaptainlevel"));

/**
 * IRequirementChecker that checks to see if the account's captain is above a certain level
 */
contract ARC_CaptainLevel is
    IAccountRequirementChecker,
    GameRegistryConsumerUpgradeable
{
    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /** Whether or not the given bytes array is valid */
    function isDataValid(
        bytes memory data
    ) external pure override returns (bool) {
        uint32 minimumLevel = abi.decode(data, (uint32));
        return minimumLevel > 0;
    }

    /**
     * This check requires data to be a serialized (uint32) for minimum level the captain must have.
     * checks to make sure the user's captain is of a certain level
     * @inheritdoc IAccountRequirementChecker
     */
    function meetsRequirement(
        address account,
        bytes memory data
    ) external view override returns (bool) {
        uint32 minimumLevel = abi.decode(data, (uint32));
        ICaptainSystem captainSystem = ICaptainSystem(
            _getSystem(CAPTAIN_SYSTEM_ID)
        );

        (address tokenContract, uint256 tokenId) = captainSystem.getCaptainNFT(
            account
        );

        ITraitsProvider traitsProvider = ITraitsProvider(
            _getSystem(TRAITS_PROVIDER_ID)
        );

        TraitCheck memory traitCheck = TraitCheck({
            checkType: TraitCheckType.TRAIT_GTE,
            traitId: LEVEL_TRAIT_ID,
            traitValue: SafeCast.toInt256(minimumLevel)
        });

        bool hasEnoughLevel = tokenId > 0 &&
            TraitsLibrary.performTraitCheck(
                traitsProvider,
                traitCheck,
                tokenContract,
                tokenId
            );
        return hasEnoughLevel;
    }
}
