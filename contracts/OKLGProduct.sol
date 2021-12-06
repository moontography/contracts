// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import './interfaces/IOKLGSpend.sol';

/**
 * @title OKLGProduct
 * @dev Contract that every product developed in the OKLG ecosystem should implement
 */
contract OKLGProduct is Ownable {
  IERC20 private _token;
  IOKLGSpend private _spend;

  uint8 public productID;

  constructor(address _tokenAddy, address _spendAddy) {
    _token = IERC20(_tokenAddy);
    _spend = IOKLGSpend(_spendAddy);
  }

  function setTokenAddy(address _tokenAddy) external onlyOwner {
    _token = IERC20(_tokenAddy);
  }

  function setSpendAddy(address _spendAddy) external onlyOwner {
    _spend = IOKLGSpend(_spendAddy);
  }

  function setProductID(uint8 _newId) external onlyOwner {
    productID = _newId;
  }

  function getTokenAddress() public view returns (address) {
    return address(_token);
  }

  function getSpendAddress() public view returns (address) {
    return address(_spend);
  }

  function _payForService(bool _paymentInETH) internal {
    _spend.spendOnProduct(msg.sender, productID, _paymentInETH);
  }
}
