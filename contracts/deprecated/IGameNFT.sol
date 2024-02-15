// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import {IERC721BridgableChild} from "./IERC721BridgableChild.sol";
import {IHoldingConsumer} from "../interfaces/IHoldingConsumer.sol";

/**
 * @title Interface for game NFTs that have stats and other properties
 */
interface IGameNFT is IHoldingConsumer, IERC721BridgableChild {

}
