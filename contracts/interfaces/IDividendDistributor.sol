// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IDividendDistributor {
  function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution)
    external;

  function setShare(
    address token,
    address shareholder,
    uint256 amount
  ) external;

  function deposit(address tokenAddress, uint256 erc20DirectAmount)
    external
    payable;
}
