// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.13;

import {PUB_SUB_ORACLE_ROLE} from "./RequestLibrary.sol";
import {EntityLibrary} from "../core/EntityLibrary.sol";
import {GameRegistryConsumerUpgradeable} from "../GameRegistryConsumerUpgradeable.sol";
import {AccountLimitComponent, Layout as AccountLimitComponentLayout, ID as ACCOUNT_LIMIT_COMPONENT_ID} from "../generated/components/AccountLimitComponent.sol";
import {ChainIdComponent, ID as CHAIN_ID_COMPONENT_ID} from "../generated/components/ChainIdComponent.sol";
import {CounterComponent, ID as COUNTER_COMPONENT_ID} from "../generated/components/CounterComponent.sol";
import {CHAIN_ENTITY, RequestLibrary} from "./RequestLibrary.sol";

uint256 constant ID = uint256(
    keccak256("game.piratenation.accountregistrysystem.v1")
);

// NOTE: DO NOT copy registration counter in case of bootstrapping a new chain
// NOTE: MUST copy registration counter in case of migrating existing chain
uint256 constant REGISTRATION_COUNTER_ENTITY = uint256(
    keccak256("game.piratenation.chainentity.v1.registrationcounter")
);

/// @notice Error thrown when new registrations are disabled
error WalletRegistrationLimitReached(
    uint256 registrationCount,
    uint256 registrationLimit
);

contract AccountRegistrySystem is GameRegistryConsumerUpgradeable {
    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    /**
     * Registers a wallet on the current chain
     *
     * @param wallet Wallet address to register
     */
    function registerWallet(
        address wallet
    ) external whenNotPaused nonReentrant onlyRole(PUB_SUB_ORACLE_ROLE) {
        CounterComponent counter = CounterComponent(
            _gameRegistry.getComponent(COUNTER_COMPONENT_ID)
        );
        uint256 registrationCount = counter.getValue(
            REGISTRATION_COUNTER_ENTITY
        );
        uint256 registrationLimit = AccountLimitComponent(
            _gameRegistry.getComponent(ACCOUNT_LIMIT_COMPONENT_ID)
        ).getValue(CHAIN_ENTITY);

        // Check if wallet registration limit has been reached
        if (registrationCount >= registrationLimit) {
            revert WalletRegistrationLimitReached(
                registrationCount,
                registrationLimit
            );
        }

        // Increment wallet registrations counter
        registrationCount++;
        counter.setValue(REGISTRATION_COUNTER_ENTITY, registrationCount);

        // Record wallet registration
        _setChainId(wallet);
    }

    /**
     * Registers multiple wallets on the current chain
     *
     * @param wallets Wallet addresses to register
     * @param isPublishing Whether to publish the registration
     */
    function batchRegisterWallets(
        address[] calldata wallets,
        bool isPublishing
    ) external whenNotPaused nonReentrant onlyRole(PUB_SUB_ORACLE_ROLE) {
        CounterComponent counter = CounterComponent(
            _gameRegistry.getComponent(COUNTER_COMPONENT_ID)
        );
        uint256 registrationCount = counter.getValue(
            REGISTRATION_COUNTER_ENTITY
        );
        uint256 registrationLimit = AccountLimitComponent(
            _gameRegistry.getComponent(ACCOUNT_LIMIT_COMPONENT_ID)
        ).getValue(CHAIN_ENTITY);

        // Check if wallet registration limit has been reached
        if (registrationCount + wallets.length > registrationLimit) {
            revert WalletRegistrationLimitReached(
                registrationCount,
                registrationLimit
            );
        }

        // Increment wallet registrations counter
        registrationCount += wallets.length;
        counter.setValue(REGISTRATION_COUNTER_ENTITY, registrationCount);

        // Record wallet registrations
        _batchSetChainId(wallets, isPublishing);
    }

    /* INTERNAL */

    function _setChainId(address wallet) internal {
        uint256 walletEntity = EntityLibrary.addressToEntity(wallet);

        ChainIdComponent(_gameRegistry.getComponent(CHAIN_ID_COMPONENT_ID))
            .setValue(walletEntity, block.chainid);

        RequestLibrary.publishCompletedComponentValueSet(
            _gameRegistry,
            CHAIN_ID_COMPONENT_ID,
            walletEntity,
            abi.encode(block.chainid)
        );
    }

    function _batchSetChainId(
        address[] memory wallets,
        bool isPublishing
    ) internal {
        bytes[] memory data = new bytes[](wallets.length);
        uint256[] memory walletEntities = new uint256[](wallets.length);

        for (uint256 i = 0; i < wallets.length; i++) {
            data[i] = abi.encode(block.chainid);
            walletEntities[i] = EntityLibrary.addressToEntity(wallets[i]);
        }

        ChainIdComponent(_gameRegistry.getComponent(CHAIN_ID_COMPONENT_ID))
            .batchSetBytes(walletEntities, data);

        if (isPublishing) {
            RequestLibrary.batchPublishCompletedComponentValueSet(
                _gameRegistry,
                CHAIN_ID_COMPONENT_ID,
                walletEntities,
                data
            );
        }
    }
}
