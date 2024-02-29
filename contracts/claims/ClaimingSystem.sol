// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";

import "../GameRegistryConsumerUpgradeable.sol";
import "../core/EntityLibrary.sol";

import {IClaimable} from "./IClaimable.sol";
import {MANAGER_ROLE} from "../Constants.sol";
import {ILootSystem, ID as LOOT_SYSTEM_ID} from "../loot/ILootSystem.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.claimingsystem"));

contract ClaimingSystem is GameRegistryConsumerUpgradeable {
    using Counters for Counters.Counter;

    // Implementation of a claim
    struct ClaimDefinition {
        // Address of the claim's implementation contract.
        address contractAddress;
        // Loots that the claimable will grant.
        ILootSystem.Loot[] loots;
        // A bytes array containing additional data for use instantiating the
        // claim. (Currently unused.)
        bytes initData;
    }

    /** MEMBERS **/
    /// @notice Mapping of claimable entity to the a struct of data (address, loot, etc.)
    // The key is also the eventEntityId -- an identifier for the eventId, used to index data
    // storage inside the claimable contracts.
    mapping(uint256 => ClaimDefinition) public claimDefinitions;

    /// @notice Mapping account to claimable entity id to a boolean of whether the claimable has been claimed.
    mapping(uint256 => mapping(uint256 => bool)) private claimingHistory;

    /** ERRORS **/
    /// @notice Claim contract's address is invalid
    error InvalidContractAddress(address invalidContractAddress);

    /// @notice ClaimId not found or not allowed.
    error InvalidClaimId(uint256 missingClaim);

    /// @notice User is trying to make a claim for which they haven't fulfilled the prerequisites.
    error NotEligibleToClaim(address account, uint256 claim);

    /// @notice User is triggering a claim that is not their own
    error NotAllowedToClaim(address msgSender, address account);

    /// @notice Invalid lengths
    error InvalidClaimLength(uint256 expected, uint256 actual);

    /** EVENTS **/

    /// @notice Emitted when a new claim contract has been registered
    event ClaimableRegistered(uint256 entity, ClaimDefinition data);

    /// @notice Emitted when a new claim contract has been registered
    event ClaimableFulfilled(
        address account,
        uint256 entity,
        ClaimDefinition data
    );

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress   Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * Register a new claimable contract.
     *
     * @param claim                 The identifier of a claim. Also used within
     *                              the claim contract to separate data for
     *                              different claims.
     * @param data                  All the information needed to define a
     *                              claim packed in to a struct.
     */
    function registerClaimable(
        uint256 claim,
        ClaimDefinition calldata data
    ) external onlyRole(MANAGER_ROLE) {
        if (claim == 0) {
            revert InvalidClaimId(claim);
        }
        claimDefinitions[claim] = data;
        ILootSystem(_getSystem(LOOT_SYSTEM_ID)).validateLoots(data.loots);
        emit ClaimableRegistered(claim, data);
    }

    function getClaimable(
        uint256 claim
    ) public view returns (ClaimDefinition memory) {
        return claimDefinitions[claim];
    }

    /**
     * Check if a player is eligible to receive a reward.
     *
     * @param account       Address of the user account interacting with the claim
     * @param claim       ID of the claim contract
     *
     */
    function canClaim(
        address account,
        uint256 claim
    ) public view returns (bool) {
        if (hasClaimed(account, claim) || account == address(0)) {
            return false;
        }
        return _getClaimImplementation(claim).canClaim(account, claim);
    }

    /**
     * Check if a player is eligible to receive a reward in bulk.
     *
     * @param account               Address of the user account interacting with the claim
     * @param claims              Array of ids of the claims to be queried
     * @return bool[]               An array of booleans such that returnArray[idx] holds
     *                              the boolean result of claims[idx].canClaim().
     *
     */
    function batchCanClaim(
        address account,
        uint256[] calldata claims
    ) public view returns (bool[] memory) {
        bool[] memory results = new bool[](claims.length);
        for (uint256 idx; idx < claims.length; ++idx) {
            results[idx] = canClaim(account, claims[idx]);
        }

        return results;
    }

    /**
     * Claim a reward for a player.
     *
     * @param account       Address of the user account interacting with the claim
     * @param claim         Entity of the claim
     *
     */
    function performClaim(
        address account,
        uint256 claim
    ) public whenNotPaused onlyAccount(account) {
        address lootSystemAddress = _getSystem(LOOT_SYSTEM_ID);

        _performClaim(account, claim, lootSystemAddress);
    }

    function batchPerformClaim(
        address account,
        uint256[] calldata claims
    ) public whenNotPaused onlyAccount(account) {
        address lootSystemAddress = _getSystem(LOOT_SYSTEM_ID);

        for (uint256 idx; idx < claims.length; ++idx) {
            uint256 claim = claims[idx];
            _performClaim(account, claim, lootSystemAddress);
        }
    }

    /**
     * Internal implementation used for performClaim and batchPerformClaim.
     *
     * @param account       Address of the user account interacting with the claim
     * @param claim         Entity of the claim
     */
    function _performClaim(
        address account,
        uint256 claim,
        address lootSystemAddress
    ) private {
        IClaimable claimable = _getClaimImplementation(claim);
        if (!canClaim(account, claim)) {
            revert NotEligibleToClaim(account, claim);
        }
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        claimingHistory[accountEntity][claim] = true;

        ILootSystem(lootSystemAddress).grantLoot(
            account,
            claimDefinitions[claim].loots
        );
        claimable.performAdditionalClaimActions(account, claim);

        emit ClaimableFulfilled(account, claim, claimDefinitions[claim]);
    }

    /**
     * Check if a player has already received a reward.
     *
     * @param account       Address of the user account interacting with the claim
     * @param claimEntity   ID of the claim contract
     *
     */
    function hasClaimed(
        address account,
        uint256 claimEntity
    ) public view returns (bool) {
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        return claimingHistory[accountEntity][claimEntity];
    }

    /**
     * Check if a player has already received a reward in bulk.
     *
     * @param account               Address of the user account interacting with the claim
     * @param claims                Array of entities of the claims to be queried
     * @return bool[]               An array of booleans such that returnArray[idx] holds
     *                              the boolean result of claims[idx].canClaim().
     *
     */
    function batchHasClaimed(
        address account,
        uint256[] calldata claims
    ) public view returns (bool[] memory) {
        bool[] memory results = new bool[](claims.length);
        for (uint256 idx; idx < claims.length; ++idx) {
            uint256 claim = claims[idx];
            results[idx] = hasClaimed(account, claim);
        }

        return results;
    }

    /**
     * @dev Sets the value of a claimed or unclaimed for a given account.
     * @param account Address of account to set as claimed
     * @param claim Claim ID to set as claimed
     * @param value Boolean value to set claimed to true or false
     */
    function setHasClaimed(
        address account,
        uint256 claim,
        bool value
    ) external onlyRole(MANAGER_ROLE) {
        uint256 accountEntity = EntityLibrary.addressToEntity(account);
        claimingHistory[accountEntity][claim] = value;
    }

    function batchSetHasClaimed(
        address[] calldata accounts,
        uint256[] calldata claims,
        bool[] calldata values
    ) external onlyRole(MANAGER_ROLE) {
        require(
            claims.length == values.length,
            "Claims and values must be the same length"
        );
        if (
            claims.length != values.length || claims.length != accounts.length
        ) {
            revert InvalidClaimLength(claims.length, values.length);
        }

        uint256 accountEntity;
        for (uint256 idx; idx < claims.length; ++idx) {
            accountEntity = EntityLibrary.addressToEntity(accounts[idx]);
            claimingHistory[accountEntity][claims[idx]] = values[idx];
        }
    }

    /**
     * Checks and returns a claim's implementation contract.
     *
     * @param claim                 Entity ID of the claim contract
     * @return claimable            An instantiated version of the claim contract
     */
    function _getClaimImplementation(
        uint256 claim
    ) private view returns (IClaimable) {
        address contractAddress = claimDefinitions[claim].contractAddress;
        if (contractAddress == address(0)) {
            revert InvalidClaimId(claim);
        }
        return IClaimable(contractAddress);
    }

    /**
     * @dev Modifier to make a function callable only by the account being passed in.
     */
    modifier onlyAccount(address account) {
        _onlyAccount(account);
        _;
    }

    function _onlyAccount(address account) private view {
        if (_getPlayerAccount(_msgSender()) != account) {
            revert NotAllowedToClaim(_msgSender(), account);
        }
    }
}
