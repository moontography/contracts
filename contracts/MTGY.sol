// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract MTGY is IERC20 {
  string public constant name = 'The moontography project';
  string public constant symbol = 'MTGY';
  uint8 public constant decimals = 18;

  mapping(address => uint256) balances;
  mapping(address => mapping(address => uint256)) allowed;

  event Spend(address indexed owner, uint256 value);

  uint256 totalSupply_;

  using SafeMath for uint256;

  constructor(uint256 total) {
    totalSupply_ = total;
    balances[msg.sender] = totalSupply_;
  }

  function totalSupply() public view override returns (uint256) {
    return totalSupply_;
  }

  function balanceOf(address tokenOwner)
    public
    view
    override
    returns (uint256)
  {
    return balances[tokenOwner];
  }

  function transfer(address receiver, uint256 numTokens)
    public
    override
    returns (bool)
  {
    require(numTokens <= balances[msg.sender]);
    balances[msg.sender] = balances[msg.sender].sub(numTokens);
    balances[receiver] = balances[receiver].add(numTokens);
    emit Transfer(msg.sender, receiver, numTokens);
    return true;
  }

  function approve(address delegate, uint256 numTokens)
    public
    override
    returns (bool)
  {
    allowed[msg.sender][delegate] = numTokens;
    emit Approval(msg.sender, delegate, numTokens);
    return true;
  }

  function allowance(address owner, address delegate)
    public
    view
    override
    returns (uint256)
  {
    return allowed[owner][delegate];
  }

  function transferFrom(
    address owner,
    address buyer,
    uint256 numTokens
  ) public override returns (bool) {
    require(numTokens <= balances[owner]);
    require(numTokens <= allowed[owner][msg.sender]);

    balances[owner] = balances[owner].sub(numTokens);
    allowed[owner][msg.sender] = allowed[owner][msg.sender].sub(numTokens);
    balances[buyer] = balances[buyer].add(numTokens);
    emit Transfer(owner, buyer, numTokens);
    return true;
  }
}
