// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

// TODO: Is this still needed now that this is no longer upgradeable?
uint256 constant ID = uint256(keccak256("game.piratenation.forwarder"));

/**
 * @dev Simple forwarder based off OZ's MinimalForwarder amd Biconomy's Forwarder to be used together with an ERC2771 compatible contract. See {ERC2771Context}.
 *
 * PopForwarder implements MinimalForwarder and adds 2d Nonces based on BiconomyForwarder's Implementation
 */
contract PopForwarder is EIP712 {
    using ECDSA for bytes32;

    struct ForwardRequest {
        address from;
        address to;
        uint256 value;
        uint256 gas;
        uint256 batchId;
        uint256 nonce;
        bytes data;
    }

    bytes32 private constant _TYPEHASH =
        keccak256(
            "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 batchId,uint256 nonce,bytes data)"
        );

    mapping(address => mapping(uint256 => uint256)) _nonces;

    constructor() EIP712("PopForwarder", "0.0.1") {}

    function getNonce(
        address from,
        uint256 batchId
    ) public view returns (uint256) {
        return _nonces[from][batchId];
    }

    function verify(
        ForwardRequest calldata req,
        bytes calldata signature
    ) public view returns (bool) {
        address signer = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    _TYPEHASH,
                    req.from,
                    req.to,
                    req.value,
                    req.gas,
                    req.batchId,
                    req.nonce,
                    keccak256(req.data)
                )
            )
        ).recover(signature);
        return
            _nonces[req.from][req.batchId] == req.nonce && signer == req.from;
    }

    function execute(
        ForwardRequest calldata req,
        bytes calldata signature
    ) public payable returns (bool, bytes memory) {
        require(
            verify(req, signature),
            "PopForwarder: signature does not match request"
        );
        _nonces[req.from][req.batchId] = req.nonce + 1;

        (bool success, bytes memory returndata) = req.to.call{
            gas: req.gas,
            value: req.value
        }(abi.encodePacked(req.data, req.from));

        // Validate that the relayer has sent enough gas for the call.
        // See https://ronan.eth.limo/blog/ethereum-gas-dangers/
        assert(gasleft() > req.gas / 63);

        _verifyCallResult(
            success,
            returndata,
            "Forwarded call to destination did not succeed"
        );

        return (success, returndata);
    }

    function getDomainSeparator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev verifies the call result and bubbles up revert reason for failed calls
     * Note: This code is based on the Forwarder code from Biconomy's Forwarder (https://github.com/bcnmy/mexa/blob/master/contracts/6/forwarder/BiconomyForwarder.sol)
     * Which uses the MIT License
     *
     * @param success : outcome of forwarded call
     * @param returndata : returned data from the frowarded call
     * @param errorMessage : fallback error message to show
     */
    function _verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) private pure {
        if (!success) {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}
