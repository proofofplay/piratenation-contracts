// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.13;

import {IGoldToken} from "./IGoldToken.sol";
import {GameRegistryConsumerUpgradeable} from "../../GameRegistryConsumerUpgradeable.sol";
import {MINTER_ROLE, GAME_LOGIC_CONTRACT_ROLE} from "../../Constants.sol";
import {GoldToken, ID as GOLD_TOKEN_ID} from "./GoldToken.sol";
import {MarkToken, ID as MARK_TOKEN_ID} from "./MarkToken.sol";
import {TradeLicenseChecks} from "../TradeLicenseChecks.sol";

uint256 constant ID = uint256(keccak256("game.piratenation.goldtokenstrategy"));

/**
 * @title Implements Strategy Pattern for Gold Token, Allowing
 * multiple IERC20 currencies to be used in any gold token contract depending on rules.
 * Only intended to be used by Internal Functions (Quest System, etc).
 * @author Proof of Play
 * @notice This implementation uses the Trade Block to determine token to use for internal game functions.
 */
contract GoldTokenStrategy is
    IGoldToken,
    GameRegistryConsumerUpgradeable,
    TradeLicenseChecks
{
    /** ERRORS **/

    /// @notice Not implemented
    error NotImplemented();

    /// @notice Trade License Present
    error TradeLicensePresent();

    /**
     * Initializer for this upgradeable contract
     *
     * @param gameRegistryAddress Address of the GameRegistry contract
     */
    function initialize(address gameRegistryAddress) public initializer {
        __GameRegistryConsumer_init(gameRegistryAddress, ID);
    }

    function mint(
        address to,
        uint256 amount
    ) external override whenNotPaused onlyRole(MINTER_ROLE) {
        if (_hasTradeLicense(to)) {
            GoldToken(_gameRegistry.getSystem(GOLD_TOKEN_ID)).mint(to, amount);
        } else {
            MarkToken(_gameRegistry.getSystem(MARK_TOKEN_ID)).mint(to, amount);
        }
    }

    function burn(
        address from,
        uint256 amount
    ) external override whenNotPaused onlyRole(MINTER_ROLE) {
        if (_hasTradeLicense(from)) {
            GoldToken(_gameRegistry.getSystem(GOLD_TOKEN_ID)).burn(
                from,
                amount
            );
        } else {
            MarkToken(_gameRegistry.getSystem(MARK_TOKEN_ID)).burn(
                from,
                amount
            );
        }
    }

    function balanceOf(address who) external view returns (uint256) {
        if (_hasTradeLicense(who)) {
            return
                GoldToken(_gameRegistry.getSystem(GOLD_TOKEN_ID)).balanceOf(
                    who
                );
        } else {
            return
                MarkToken(_gameRegistry.getSystem(MARK_TOKEN_ID)).balanceOf(
                    who
                );
        }
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override whenNotPaused onlyRole(MINTER_ROLE) returns (bool) {
        if (_hasTradeLicense(from)) {
            return
                GoldToken(_gameRegistry.getSystem(GOLD_TOKEN_ID)).transferFrom(
                    from,
                    to,
                    amount
                );
        } else {
            return
                MarkToken(_gameRegistry.getSystem(MARK_TOKEN_ID)).transferFrom(
                    from,
                    to,
                    amount
                );
        }
    }

    /**
     * Called only when a user consumes a Trade License
     * @param who Address of account being upgraded
     */
    function tradeLicenseWasEnabled(
        address who
    ) external whenNotPaused onlyRole(GAME_LOGIC_CONTRACT_ROLE) {
        MarkToken markToken = MarkToken(_gameRegistry.getSystem(MARK_TOKEN_ID));

        uint256 balance = markToken.balanceOf(who);
        if (balance > 0) {
            markToken.burn(who, balance);
            GoldToken(_gameRegistry.getSystem(GOLD_TOKEN_ID)).mint(
                who,
                balance
            );
        }
    }

    /**
     * @dev Converts Gold to Marks
     * Only for accounts that dont have a trade license
     * @param amountOfGold Amount of Gold to convert
     */
    function convertGoldToMarks(
        uint256 amountOfGold
    ) external nonReentrant whenNotPaused {
        address account = _getPlayerAccount(_msgSender());
        if (_hasTradeLicense(account) == true) {
            revert TradeLicensePresent();
        }
        MarkToken(_gameRegistry.getSystem(MARK_TOKEN_ID)).mint(
            account,
            amountOfGold
        );
        GoldToken(_gameRegistry.getSystem(GOLD_TOKEN_ID)).burn(
            account,
            amountOfGold
        );
    }

    /**
     * Fall over to PGLD for most static traits.
     */
    function totalSupply() external view returns (uint256) {
        return GoldToken(_gameRegistry.getSystem(GOLD_TOKEN_ID)).totalSupply();
    }

    function name() external view returns (string memory) {
        return GoldToken(_gameRegistry.getSystem(GOLD_TOKEN_ID)).name();
    }

    function symbol() external view returns (string memory) {
        return GoldToken(_gameRegistry.getSystem(GOLD_TOKEN_ID)).symbol();
    }

    function decimals() external view returns (uint8) {
        return GoldToken(_gameRegistry.getSystem(GOLD_TOKEN_ID)).decimals();
    }

    // These functions below need to be implemented to be IGameCurrency, but will not be used
    // Kind of sucks we inherited from IERC20 for this.

    function transfer(address, uint256) external pure returns (bool) {
        revert NotImplemented();
    }

    function approve(address, uint256) external pure returns (bool) {
        revert NotImplemented();
    }

    function allowance(address, address) external pure returns (uint256) {
        revert NotImplemented();
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
