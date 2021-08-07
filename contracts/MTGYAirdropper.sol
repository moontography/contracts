// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './MTGYSpend.sol';

/**
 * @title MTGYAirdropper
 * @dev Allows sending an ERC20 token to multiple addresses in different amounts
 */
contract MTGYAirdropper is Ownable {
  ERC20 private _mtgy;
  MTGYSpend private _mtgySpend;

  address public mtgyTokenAddy;
  address public mtgySpendAddy;
  uint256 public mtgyServiceCost = 5000 * 10**18;

  struct Receiver {
    address userAddress;
    uint256 amountToReceive;
  }

  constructor(address _mtgyTokenAddy, address _mtgySpendAddy) {
    mtgyTokenAddy = _mtgyTokenAddy;
    mtgySpendAddy = _mtgySpendAddy;
    _mtgy = ERC20(_mtgyTokenAddy);
    _mtgySpend = MTGYSpend(_mtgySpendAddy);
  }

  function changeMtgyTokenAddy(address _tokenAddy) external onlyOwner {
    mtgyTokenAddy = _tokenAddy;
    _mtgy = ERC20(_tokenAddy);
  }

  function changeMtgySpendAddy(address _spendAddy) external onlyOwner {
    mtgySpendAddy = _spendAddy;
    _mtgySpend = MTGYSpend(_spendAddy);
  }

  function changeServiceCost(uint256 _newCost) external onlyOwner {
    mtgyServiceCost = _newCost;
  }

  function bulkSendMainTokens(Receiver[] memory _addressesAndAmounts)
    external
    payable
    returns (bool)
  {
    _payForService();

    bool _wasSent = true;

    for (uint256 _i = 0; _i < _addressesAndAmounts.length; _i++) {
      Receiver memory _user = _addressesAndAmounts[_i];
      (bool sent, ) = _user.userAddress.call{ value: _user.amountToReceive }(
        ''
      );
      _wasSent = _wasSent == false ? false : sent;
    }
    return _wasSent;
  }

  function bulkSendErc20Tokens(
    address _tokenAddress,
    Receiver[] memory _addressesAndAmounts
  ) external returns (bool) {
    _payForService();

    ERC20 _token = ERC20(_tokenAddress);
    for (uint256 _i = 0; _i < _addressesAndAmounts.length; _i++) {
      Receiver memory _user = _addressesAndAmounts[_i];
      _token.transferFrom(msg.sender, _user.userAddress, _user.amountToReceive);
    }
    return true;
  }

  function _payForService() private {
    _mtgy.transferFrom(msg.sender, address(this), mtgyServiceCost);
    _mtgy.approve(mtgySpendAddy, mtgyServiceCost);
    _mtgySpend.spendOnProduct(mtgyServiceCost);
  }
}
