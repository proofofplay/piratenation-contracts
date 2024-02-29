// SPDX-License-Identifier: MIT

/**
 * @title An extension of ReentrancyGuardUpgradeable based on https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/security/ReentrancyGuardUpgradeable.sol
 * Adds a modifier beforeTransferReentrantCheck that allows the BFT to fire once, but not again and silent return if within Same Contract
 * @author Proof of Play
 * @notice
 */

pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract TokenReentrancyGuardUpgradable is Initializable {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private constant _ENTERED_BEFORETRANSFER = 3;

    uint256 private _status;
    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    function __TokenReentrancyGuard_init() internal onlyInitializing {
        __TokenReentrancyGuard_init_unchained();
    }

    function __TokenReentrancyGuard_init_unchained() internal onlyInitializing {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier reentrantCheck() {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        if (_status > _NOT_ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
        _;
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev A special case of the nonReentant that skips if status is entered, and reverts if entered bft.
     * The idea here is that we want to allow the above check in once (so, for example, contract calls safetransferhook, then a subsequent call gets to this method)
     * We want to allow that silently (so return silently in this case) then revert if this function is called twice.
     */
    modifier beforeTransferReentrantCheck() {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        if (_status == _ENTERED) {
            return; // Silent returns here to allow no events from a trade made on this contract.
        }

        if (_status == _ENTERED_BEFORETRANSFER) {
            revert ReentrancyGuardReentrantCall(); // hard reverts here to deal with reentrant attack.
        }

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED_BEFORETRANSFER;
        _;
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardBFTEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
