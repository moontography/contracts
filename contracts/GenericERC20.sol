// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract GenericERC20 is ERC20 {
  constructor(string memory _name, string memory _symbol)
    ERC20(_name, _symbol)
  {
    _mint(msg.sender, 1_000_000 * 10**18);
  }
}
