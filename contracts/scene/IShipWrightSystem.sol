// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

uint256 constant ID = uint256(keccak256("game.piratenation.shipwrightsystem"));

struct UpgradeShipInput {
    // Entity of the ship to burn
    uint256 shipToBurnEntity;
    // Entity of the ship to upgrade
    uint256 shipToUpgradeEntity;
    // Unique guid of the ShipWright on the island
    uint256 instanceEntity;
    // Entity of the ShipPlan craft to use
    uint256 shipPlanEntity;
}

/// @title Interface for the ShipWrightSystem
interface IShipWrightSystem {
    /**
     * @dev Ship merging functionality of ShipWright
     */
    function upgradeShip(UpgradeShipInput calldata input) external;

    /**
     * Set ShipWright as public or private
     */
    function setShipWrightPublic(
        uint256 instanceEntity,
        uint256 status
    ) external;

    /**
     * @dev ShipWright upgrading functionality of ShipWright
     */
    function upgradeShipWright(uint256 instanceEntity) external;

    /**
     * @dev ShipWright trigger cooldown upon placement on island
     */
    function initializeCooldownIfShipwright(
        uint256 instanceEntity,
        address account,
        uint256 islandEntity
    ) external;
}
