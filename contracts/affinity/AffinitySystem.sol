// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {IGameGlobals, ID as GAME_GLOBALS_ID} from "../gameglobals/IGameGlobals.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.affinitysystem"));

uint256 constant FIRE_ID = uint256(keccak256("affinity.damagemultiplier.fire"));
uint256 constant WATER_ID = uint256(
    keccak256("affinity.damagemultiplier.water")
);
uint256 constant EARTH_ID = uint256(
    keccak256("affinity.damagemultiplier.earth")
);
uint256 constant AIR_ID = uint256(keccak256("affinity.damagemultiplier.air"));
uint256 constant LIGHTNING_ID = uint256(
    keccak256("affinity.damagemultiplier.lightning")
);

int256 constant AFFINITY_PRECISION_FACTOR = 10000;

enum AffinityTypes {
    UNDEFINED,
    FIRE,
    WATER,
    EARTH,
    AIR,
    LIGHTNING
}

contract AffinitySystem is GameRegistryConsumerUpgradeable {
    mapping(uint256 => uint256) _affinityToGlobal;

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);

        _affinityToGlobal[uint256(AffinityTypes.FIRE)] = FIRE_ID;
        _affinityToGlobal[uint256(AffinityTypes.WATER)] = WATER_ID;
        _affinityToGlobal[uint256(AffinityTypes.EARTH)] = EARTH_ID;
        _affinityToGlobal[uint256(AffinityTypes.AIR)] = AIR_ID;
        _affinityToGlobal[uint256(AffinityTypes.LIGHTNING)] = LIGHTNING_ID;
    }

    /**
     * Takes two damage modifiers and returns a percentage to multiply by
     * @param affinityA affinity you have
     * @param affinityB affinity you will be doing damage to
     * @return damageModifier amount in % you will modify (multiply) for that affinity
     */
    function getDamageModifier(
        uint256 affinityA,
        uint256 affinityB
    ) public view returns (uint256) {
        IGameGlobals gameGlobals = IGameGlobals(_getSystem(GAME_GLOBALS_ID));

        uint256[] memory damageModifiers = gameGlobals.getUint256Array(
            _affinityToGlobal[affinityA]
        );

        return damageModifiers[affinityB];
    }
}
