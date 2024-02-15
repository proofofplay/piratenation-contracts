// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

uint256 constant ID = uint256(keccak256("game.piratenation.energysystem"));

/// @title Interface for the EnergySystem that lets tokens have energy associated with them
interface IEnergySystem {
    /**
     * Gives energy to the given token
     *
     * @param tokenContract Contract to give energy to
     * @param tokenId       Token id to give energy to
     * @param amount        Amount of energy to give
     */
    function giveEnergy(
        address tokenContract,
        uint256 tokenId,
        uint256 amount
    ) external;

    /**
     * Spends energy for the given token
     *
     * @param tokenContract Contract to spend energy for
     * @param tokenId       Token id to spend energy for
     * @param amount        Amount of energy to spend
     */
    function spendEnergy(
        address tokenContract,
        uint256 tokenId,
        uint256 amount
    ) external;

    /**
     * @param tokenContract Contract to get milestones for
     * @param tokenId       Token id to get milestones for
     *
     * @return The amount of energy the token currently has
     */
    function getEnergy(
        address tokenContract,
        uint256 tokenId
    ) external view returns (uint256);
}

/// @title Interface for the EnergySystem that lets tokens have energy associated with them
interface IEnergySystemV3 {
    /**
     * Gives energy to the given entity
     *
     * @param entity        Entity to give energy to
     * @param amount        Amount of energy to give
     */
    function giveEnergy(uint256 entity, uint256 amount) external;

    /**
     * Spends energy for the given entity
     *
     * @param entity        Entity to spend energy for
     * @param amount        Amount of energy to spend
     */
    function spendEnergy(uint256 entity, uint256 amount) external;

    /**
     * @param entity Entity to get energy for
     *
     * @return The amount of energy the token currently has
     */
    function getEnergy(uint256 entity) external view returns (uint256);
}
