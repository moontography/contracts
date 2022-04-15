//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './interfaces/IOKLGRewardDistributor.sol';

contract proxyOKLG is ERC20 {
  address public OKLGContract;
  address public owner;
  address public OKLGStakingContract;
  bool public factorNFTBoost = false;

  modifier onlyOwner() {
    require(msg.sender == owner, 'Only owner can call this function');
    _;
  }

  constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    owner = msg.sender;
  }

  function transfer(address recipient, uint256 amount)
    public
    override
    returns (bool)
  {
    revert('This proxy token is not transferable');
  }

  function balanceOf(address _account) public view override returns (uint256) {
    uint256 _stakedBalance = factorNFTBoost
      ? IOKLGRewardDistributor(OKLGStakingContract).getShares(_account)
      : IOKLGRewardDistributor(OKLGStakingContract).getBaseShares(_account);
    uint256 _balance = IERC20(OKLGContract).balanceOf(_account);
    uint256 _totalBalance = _stakedBalance + _balance;

    return _totalBalance;
  }

  function setOKLGContract(address _OKLGContract) external onlyOwner {
    OKLGContract = _OKLGContract;
  }

  function setOKLGStakingContract(address _OKLGStakingContract)
    external
    onlyOwner
  {
    OKLGStakingContract = _OKLGStakingContract;
  }

  function setFactorNFTBoost(bool _factorNFTBoost) external onlyOwner {
    factorNFTBoost = _factorNFTBoost;
  }
}
