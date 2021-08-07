// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * @title MTGYAtomicSwapInstHash
 * @dev Hash an address, timestamp, amount like that happens in MTGYAtomicSwapInstance.sol
 */
contract MTGYAtomicSwapInstHash {
  function hash(
    address _addy,
    uint256 _ts,
    uint256 _amount
  ) external pure returns (bytes32) {
    return sha256(abi.encodePacked(_addy, _ts, _amount));
  }
}
