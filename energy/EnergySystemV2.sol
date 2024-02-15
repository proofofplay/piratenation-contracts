// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {MANAGER_ROLE, GAME_NFT_CONTRACT_ROLE, GAME_LOGIC_CONTRACT_ROLE} from "../Constants.sol";
import "../libraries/GameHelperLibrary.sol";

import {IEnergySystem, ID} from "./IEnergySystem.sol";

import {IGameGlobals, ID as GAME_GLOBALS_ID} from "../gameglobals/IGameGlobals.sol";
import {ITraitsProvider, ID as TRAITS_PROVIDER_ID} from "../interfaces/ITraitsProvider.sol";
import "../GameRegistryConsumerUpgradeable.sol";

// Globals used by this contract
uint256 constant MAX_ENERGY_PER_LEVEL_ID = uint256(
    keccak256("max_energy_per_level")
);
uint256 constant ENERGY_REGEN_SECS_PER_LEVEL_ID = uint256(
    keccak256("energy_regen_secs_per_level")
);
/// @dev Minimum energy the player must receive otherwise will be reverted
uint256 constant MIN_ENERGY_EARNABLE = 1 ether;
uint256 constant MAX_ENERGY_EARNABLE_ID = uint256(
    keccak256("max_energy_earnable")
);
uint256 constant ENERGY_EARNABLE_REGEN_SECS_ID = uint256(
    keccak256("energy_earnable_regen_secs")
);
// Data for each token
struct TokenData {
    // Last time energy was spent
    uint256 lastSpendTimestamp;
    // Energy amount at time of last spend
    uint256 lastEnergyAmount;
    // Energy allowed to be earned
    uint256 lastEnergyEarnable;
    // Last time energy was earned
    uint256 lastEarnTimestamp;
}

/**
 * @title EnergySystemV2
 *
 * Tracks energy accumulation and spend for a given token
 * Note: Energy is measured in ETHER units so we can do fractional energy
 */
contract EnergySystemV2 is IEnergySystem, GameRegistryConsumerUpgradeable {
    /// @notice Data for each token
    mapping(address => mapping(uint256 => TokenData)) private _tokenData;

    /** EVENTS */

    /// @notice Emitted when the user has gained some energy
    event EnergyGained(
        address indexed owner,
        address indexed tokenContract,
        uint256 indexed tokenId,
        uint256 amountGained,
        uint256 lastEnergyEarnable
    );

    /// @notice Emitted when the user has spent some energy
    event EnergySpent(
        address indexed owner,
        address indexed tokenContract,
        uint256 indexed tokenId,
        uint256 amountSpent,
        uint256 lastEnergyAmount
    );

    /** ERRORS */

    /// @notice Emitted when a contract is not a GameNFT
    error ContractNotGameNFT(address tokenContract);

    /// @notice Emitted when a contract is not active for this system
    error ContractNotActive(address tokenContract);

    /// @notice Emitted when a token does not have enough energy
    error NotEnoughEnergy(uint256 expected, uint256 actual);

    /// @notice Emitted when a token does is at max energy
    error AtMaxEnergy(uint256 current, uint256 max);

    /// @notice Emitted when a token cant earn energy
    error CannotEarnEnergy();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

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
    ) external whenNotPaused nonReentrant onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        uint256 maxEnergy = _maxEnergy(tokenContract, tokenId);
        uint256 currentEnergyEarnable = _energyEarnableForToken(
            tokenContract,
            tokenId
        );

        if (maxEnergy == 0 || currentEnergyEarnable < MIN_ENERGY_EARNABLE) {
            revert CannotEarnEnergy();
        }
        TokenData storage tokenData = _tokenData[tokenContract][tokenId];
        uint256 currentEnergy = _energyForToken(tokenContract, tokenId);

        // This should be okay because of the way spend energy works, it won't let the user go over their max
        if (currentEnergy >= maxEnergy) {
            revert AtMaxEnergy(currentEnergy, maxEnergy);
        }
        uint256 amountToEarn = amount;

        if (amountToEarn > currentEnergyEarnable) {
            amountToEarn = currentEnergyEarnable;
        }

        tokenData.lastEnergyAmount += amountToEarn;
        if (tokenData.lastEnergyAmount > maxEnergy) {
            amountToEarn -= tokenData.lastEnergyAmount - maxEnergy;
            tokenData.lastEnergyAmount = maxEnergy;
        }

        uint256 lastEnergyEarnable = currentEnergyEarnable - amountToEarn;
        tokenData.lastEnergyEarnable = lastEnergyEarnable;
        tokenData.lastEarnTimestamp = SafeCast.toUint32(block.timestamp);

        // Emit event
        emit EnergyGained(
            _msgSender(),
            tokenContract,
            tokenId,
            amountToEarn,
            lastEnergyEarnable
        );
    }

    /**
     * Spends energy for the given token
     *
     * @param tokenContract Contract to get milestones for
     * @param tokenId       Token id to get milestones for
     * @param amount        Amount of energy to spend
     */
    function spendEnergy(
        address tokenContract,
        uint256 tokenId,
        uint256 amount
    ) external whenNotPaused nonReentrant onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        uint256 currentEnergy = _energyForToken(tokenContract, tokenId);
        if (currentEnergy < amount) {
            revert NotEnoughEnergy(amount, currentEnergy);
        }

        TokenData storage tokenData = _tokenData[tokenContract][tokenId];

        // Store new energy info
        uint256 lastEnergyAmount = currentEnergy - amount;
        tokenData.lastEnergyAmount = lastEnergyAmount;
        tokenData.lastSpendTimestamp = SafeCast.toUint32(block.timestamp);

        // Emit event
        emit EnergySpent(
            _msgSender(),
            tokenContract,
            tokenId,
            amount,
            lastEnergyAmount
        );
    }

    /**
     * @param tokenContract Contract to get milestones for
     * @param tokenId       Token id to get milestones for
     *
     * @return The amount of current amount of energy for a token
     */
    function getEnergy(
        address tokenContract,
        uint256 tokenId
    ) external view override returns (uint256) {
        return _energyForToken(tokenContract, tokenId);
    }

    /**
     * @param tokenContract Contract to get milestones for
     * @param tokenId       Token id to get milestones for
     *
     * @return The current amount of energy earnable
     */
    function getEnergyEarnable(
        address tokenContract,
        uint256 tokenId
    ) external view returns (uint256) {
        return _energyEarnableForToken(tokenContract, tokenId);
    }

    /**
     * Retrieves energy regen info for a given token.
     *
     * @param tokenContract Contract to get milestones for
     * @param tokenId       Token id to get milestones for
     *
     * @return currentEnergy            Current amount of energy the token has
     * @return maxEnergy                Maximum amount of energy the token can hold at once
     * @return energyRegenPerSecond     Rate the token accumulates new energy
     * @return lastSpendTimestamp       Last time energy was spent for this token
     * @return lastEnergyAmount         How much energy was left after last spend    Max energy can earn value
     * @return currentEnergyEarnable    Current earnable energy
     * @return lastEnergyEarnable       How much energy could be earned after last earn
     * @return lastEarnTimestamp        Last time energy was earned for this token
     * @return earnableRegenPerSecond    Rate the tokens earn limit restores
     * @return maxEnergyEarnable        Max energy can earn value
     */
    function getTokenData(
        address tokenContract,
        uint256 tokenId
    )
        external
        view
        returns (
            uint256 currentEnergy,
            uint256 maxEnergy,
            uint256 energyRegenPerSecond,
            uint256 lastSpendTimestamp,
            uint256 lastEnergyAmount,
            uint256 currentEnergyEarnable,
            uint256 lastEnergyEarnable,
            uint256 lastEarnTimestamp,
            uint256 earnableRegenPerSecond,
            uint256 maxEnergyEarnable
        )
    {
        TokenData storage data = _tokenData[tokenContract][tokenId];

        currentEnergy = _energyForToken(tokenContract, tokenId);
        maxEnergy = _maxEnergy(tokenContract, tokenId);
        energyRegenPerSecond = _energyRegenPerSecond(tokenContract, tokenId);
        lastEnergyAmount = data.lastEnergyAmount;
        lastSpendTimestamp = data.lastSpendTimestamp;
        currentEnergyEarnable = _energyEarnableForToken(tokenContract, tokenId);
        lastEnergyEarnable = data.lastEnergyEarnable;
        lastEarnTimestamp = data.lastEarnTimestamp;
        earnableRegenPerSecond = _energyEarnableRegenPerSecond();
        maxEnergyEarnable = _maxEnergyEarnable();
    }

    /** INTERNAL */
    function _maxEnergy(
        address tokenContract,
        uint256 tokenId
    ) internal view returns (uint256) {
        IGameGlobals gameGlobals = IGameGlobals(_getSystem(GAME_GLOBALS_ID));

        uint256[] memory maxEnergyPerLevel = gameGlobals.getUint256Array(
            MAX_ENERGY_PER_LEVEL_ID
        );

        ITraitsProvider traitsProvider = ITraitsProvider(
            _getSystem(TRAITS_PROVIDER_ID)
        );

        uint256 currentLevel = GameHelperLibrary._levelForPirate(
            traitsProvider,
            tokenContract,
            tokenId
        );

        if (currentLevel == 0) {
            return 0;
        }

        if (currentLevel < maxEnergyPerLevel.length) {
            return maxEnergyPerLevel[currentLevel];
        } else {
            return maxEnergyPerLevel[maxEnergyPerLevel.length - 1];
        }
    }

    function _energyRegenPerSecond(
        address tokenContract,
        uint256 tokenId
    ) internal view returns (uint256) {
        IGameGlobals gameGlobals = IGameGlobals(_getSystem(GAME_GLOBALS_ID));

        uint256[] memory energyRegenSecsPerLevel = gameGlobals.getUint256Array(
            ENERGY_REGEN_SECS_PER_LEVEL_ID
        );

        ITraitsProvider traitsProvider = ITraitsProvider(
            _getSystem(TRAITS_PROVIDER_ID)
        );

        uint256 currentLevel = GameHelperLibrary._levelForPirate(
            traitsProvider,
            tokenContract,
            tokenId
        );

        uint256 regenSecs;
        if (currentLevel < energyRegenSecsPerLevel.length) {
            regenSecs = energyRegenSecsPerLevel[currentLevel];
        } else {
            regenSecs = energyRegenSecsPerLevel[
                energyRegenSecsPerLevel.length - 1
            ];
        }

        // 1 energy unit per hour
        return uint256(1 ether) / regenSecs;
    }

    function _energyForToken(
        address tokenContract,
        uint256 tokenId
    ) internal view returns (uint256) {
        TokenData storage tokenData = _tokenData[tokenContract][tokenId];
        uint256 maxEnergy = _maxEnergy(tokenContract, tokenId);

        // Prevent overflows by defaulting to max energy if energy has never been spent before on this token
        if (tokenData.lastSpendTimestamp == 0) {
            return maxEnergy;
        }

        uint256 energyAccumulated = tokenData.lastEnergyAmount +
            (block.timestamp - tokenData.lastSpendTimestamp) *
            _energyRegenPerSecond(tokenContract, tokenId);

        if (energyAccumulated > maxEnergy) {
            return maxEnergy;
        } else {
            return energyAccumulated;
        }
    }

    function _energyEarnableForToken(
        address tokenContract,
        uint256 tokenId
    ) internal view returns (uint256) {
        TokenData storage tokenData = _tokenData[tokenContract][tokenId];

        uint256 maxEnergyEarnable = _maxEnergyEarnable();

        // Prevent overflows by defaulting to max energy if energy has never been spent before on this token
        if (tokenData.lastEarnTimestamp == 0) {
            return maxEnergyEarnable;
        }

        uint256 energyEarnableAccumulated = tokenData.lastEnergyEarnable + //0 + 0
            (block.timestamp - tokenData.lastEarnTimestamp) *
            _energyEarnableRegenPerSecond();

        if (energyEarnableAccumulated > maxEnergyEarnable) {
            return maxEnergyEarnable;
        } else {
            return energyEarnableAccumulated;
        }
    }

    function _maxEnergyEarnable() internal view returns (uint256) {
        IGameGlobals gameGlobals = IGameGlobals(_getSystem(GAME_GLOBALS_ID));

        uint256 maxEnergyEarnable = gameGlobals.getUint256(
            MAX_ENERGY_EARNABLE_ID
        );

        return maxEnergyEarnable;
    }

    function _energyEarnableRegenPerSecond() internal view returns (uint256) {
        IGameGlobals gameGlobals = IGameGlobals(_getSystem(GAME_GLOBALS_ID));

        uint256 energyEarnableRegenSecs = gameGlobals.getUint256(
            ENERGY_EARNABLE_REGEN_SECS_ID
        );

        // 1 energy unit per hour
        return uint256(1 ether) / energyEarnableRegenSecs;
    }
}
