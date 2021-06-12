// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import './MTGY.sol';

/**
 * @title MTGYSpend
 * @dev Logic for spending $MTGY on products in the moontography ecosystem.
 */
contract MTGYSpend {
  MTGY private _token;

  struct SpentInfo {
    uint256 timestamp;
    uint256 tokens;
  }

  address public creator;
  address public constant burnWallet =
    0x000000000000000000000000000000000000dEaD;
  address public devWallet = 0x3A3ffF4dcFCB7a36dADc40521e575380485FA5B8;
  address public rewardsWallet = 0x87644cB97C1e2Cc676f278C88D0c4d56aC17e838;
  address public mtgyTokenAddy;

  SpentInfo[] public spentTimestamps;
  uint256 public totalSpent = 0;

  event Spend(address indexed owner, uint256 value);

  constructor(address _mtgyTokenAddy) {
    creator = msg.sender;
    mtgyTokenAddy = _mtgyTokenAddy;
    _token = MTGY(_mtgyTokenAddy);
  }

  function changeMtgyTokenAddy(address _tokenAddy) public {
    require(
      msg.sender == creator,
      'changeMtgyTokenAddy user must be contract creator'
    );
    mtgyTokenAddy = _tokenAddy;
    _token = MTGY(_tokenAddy);
  }

  function changeDevWallet(address _newDevWallet) public {
    require(
      msg.sender == creator,
      'changeDevWallet user must be contract creator'
    );
    devWallet = _newDevWallet;
  }

  function changeRewardsWallet(address _newRewardsWallet) public {
    require(
      msg.sender == creator,
      'changeRewardsWallet user must be contract creator'
    );
    rewardsWallet = _newRewardsWallet;
  }

  function getSpentByTimestamp() public view returns (SpentInfo[] memory) {
    return spentTimestamps;
  }

  /**
   * spendOnProduct: used by a moontography product for a user to spend their tokens on usage of a product
   *   25% goes to dev wallet
   *   25% goes to rewards wallet for rewards
   *   50% burned
   */
  function spendOnProduct(uint256 _productCostTokens) public returns (bool) {
    totalSpent += _productCostTokens;
    spentTimestamps.push(
      SpentInfo({ timestamp: block.timestamp, tokens: _productCostTokens })
    );
    uint256 _half = _productCostTokens / uint256(2);
    uint256 _quarter = _half / uint256(2);

    // 50% burn
    _token.transferFrom(msg.sender, burnWallet, _half);
    // 25% rewards wallet
    _token.transferFrom(msg.sender, rewardsWallet, _quarter);
    // 25% dev wallet
    _token.transferFrom(
      msg.sender,
      devWallet,
      _productCostTokens - _half - _quarter
    );
    emit Spend(msg.sender, _productCostTokens);
    return true;
  }
}
