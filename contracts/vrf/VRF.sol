// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./IVRFConsumer.sol";

contract VRF is AccessControl, ReentrancyGuard {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant CONSUMER_ROLE = keccak256("CONSUMER_ROLE");

    mapping(uint256 => IVRFConsumer) private _callbacks;
    uint256 private _requestId;

    event RequestRandomNumber(uint256 indexed requestId);
    event RandomNumberDelivered(uint256 indexed requestId, uint256 number);

    constructor(address owner) {
        _requestId = 0;
        _setupRole(DEFAULT_ADMIN_ROLE, owner);
    }

    function request()
        external
        onlyRole(CONSUMER_ROLE)
        nonReentrant
        returns (uint256)
    {
        _requestId++;
        _callbacks[_requestId] = IVRFConsumer(msg.sender);
        emit RequestRandomNumber(_requestId);
        return _requestId;
    }

    function oracleCallback(
        uint256 id,
        uint256 value
    ) public onlyRole(ORACLE_ROLE) nonReentrant {
        //todo: do we care about number of times called? we could have a parity of 3?
        _callbacks[id].recievedRandomNumber(id, value);
        delete _callbacks[id];
        emit RandomNumberDelivered(id, value);
    }
}
