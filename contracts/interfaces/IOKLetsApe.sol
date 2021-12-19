// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

/**
 * @dev Interface that can be used to build custom logic to get mint cost.
 */
interface IOKLetsApe {
  /**
   * @dev Returns mint cost in wei.
   */
  function mintCost() external view returns (uint256);
}
