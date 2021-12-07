// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/interfaces/IERC20.sol';
import './interfaces/IOKLGSpend.sol';
import './OKLGWithdrawable.sol';

/**
 * @title OKLGSpend
 * @dev Logic for spending OKLG on products in the product ecosystem.
 */
contract OKLGSpend is IOKLGSpend, OKLGWithdrawable {
  IERC20 private _paymentToken;

  address payable private constant _deadWallet =
    payable(0x000000000000000000000000000000000000dEaD);
  address payable public targetWallet =
    payable(0x000000000000000000000000000000000000dEaD);

  uint256 public totalSpentETH = 0;
  mapping(uint8 => uint256) public defaultProductPriceETH;
  mapping(address => uint256) public overrideProductPriceETH;
  mapping(address => bool) public removeCost;
  event Spend(address indexed user, address indexed product, uint256 value);

  constructor(address _tokenAddy) {
    _paymentToken = IERC20(_tokenAddy);
  }

  function getPaymentToken() external view returns (address) {
    return address(_paymentToken);
  }

  function setTokenAddy(address _tokenAddy) external onlyOwner {
    _paymentToken = IERC20(_tokenAddy);
  }

  function setDestWallet(address _newDestWallet) external onlyOwner {
    targetWallet = payable(_newDestWallet);
  }

  function setDefaultProductETHPrice(uint8 _product, uint256 _priceETH)
    external
    onlyOwner
  {
    defaultProductPriceETH[_product] = _priceETH;
  }

  function setDefaultProductPricesETHBulk(
    uint8[] memory _productIds,
    uint256[] memory _pricesETH
  ) external onlyOwner {
    require(
      _productIds.length == _pricesETH.length,
      'arrays need to be the same length'
    );
    for (uint256 _i = 0; _i < _productIds.length; _i++) {
      defaultProductPriceETH[_productIds[_i]] = _pricesETH[_i];
    }
  }

  function setOverrideProductPriceETH(address _productCont, uint256 _priceETH)
    external
    onlyOwner
  {
    overrideProductPriceETH[_productCont] = _priceETH;
  }

  function setOverrideProductPricesETHBulk(
    address[] memory _contracts,
    uint256[] memory _pricesETH
  ) external onlyOwner {
    require(
      _contracts.length == _pricesETH.length,
      'arrays need to be the same length'
    );
    for (uint256 _i = 0; _i < _contracts.length; _i++) {
      overrideProductPriceETH[_contracts[_i]] = _pricesETH[_i];
    }
  }

  function setRemoveCost(address _productCont, bool _isRemoved)
    external
    onlyOwner
  {
    removeCost[_productCont] = _isRemoved;
  }

  /**
   * spendOnProduct: used by an OKLG product for a user to spend native token on usage of a product
   */
  function spendOnProduct(address _payor, uint8 _product)
    external
    payable
    override
  {
    if (removeCost[msg.sender]) return;

    uint256 _productCostETH = overrideProductPriceETH[msg.sender] > 0
      ? overrideProductPriceETH[msg.sender]
      : defaultProductPriceETH[_product];
    require(
      msg.value >= _productCostETH,
      'not enough ETH sent to pay for product'
    );
    address payable _paymentWallet = targetWallet == _deadWallet ||
      targetWallet == address(0)
      ? payable(owner())
      : targetWallet;
    _paymentWallet.call{ value: _productCostETH }('');
    totalSpentETH += _productCostETH;
    emit Spend(msg.sender, _payor, _productCostETH);
  }
}
