// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import './interfaces/IOKLGSpend.sol';
import './OKLGWithdrawable.sol';

/**
 * @title OKLGSpendNative
 * @dev Logic for spending OKLG on products in the product ecosystem, and uses
 *      native token instead of Wei pegged prices.
 */
contract OKLGSpendNative is IOKLGSpend, OKLGWithdrawable {
  address payable private constant DEAD_WALLET =
    payable(0x000000000000000000000000000000000000dEaD);
  address payable public paymentWallet =
    payable(0x000000000000000000000000000000000000dEaD);

  uint256 public totalSpentWei = 0;
  mapping(uint8 => uint256) public defaultProductPriceWei;
  mapping(address => uint256) public overrideProductPriceWei;
  mapping(address => bool) public removeCost;
  event Spend(address indexed user, address indexed product, uint256 value);

  function setPaymentWallet(address _newPaymentWallet) external onlyOwner {
    paymentWallet = payable(_newPaymentWallet);
  }

  function setDefaultProductWeiPrice(uint8 _product, uint256 _priceWei)
    external
    onlyOwner
  {
    defaultProductPriceWei[_product] = _priceWei;
  }

  function setdefaultProductPriceWeisWeiBulk(
    uint8[] memory _productIds,
    uint256[] memory _pricesWei
  ) external onlyOwner {
    require(
      _productIds.length == _pricesWei.length,
      'arrays need to be the same length'
    );
    for (uint256 _i = 0; _i < _productIds.length; _i++) {
      defaultProductPriceWei[_productIds[_i]] = _pricesWei[_i];
    }
  }

  function setoverrideProductPriceWei(address _productCont, uint256 _priceWei)
    external
    onlyOwner
  {
    overrideProductPriceWei[_productCont] = _priceWei;
  }

  function setoverrideProductPriceWeisWeiBulk(
    address[] memory _contracts,
    uint256[] memory _pricesWei
  ) external onlyOwner {
    require(
      _contracts.length == _pricesWei.length,
      'arrays need to be the same length'
    );
    for (uint256 _i = 0; _i < _contracts.length; _i++) {
      overrideProductPriceWei[_contracts[_i]] = _pricesWei[_i];
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

    uint256 _productCostWei = overrideProductPriceWei[msg.sender] > 0
      ? overrideProductPriceWei[msg.sender]
      : defaultProductPriceWei[_product];
    if (_productCostWei == 0) return;

    require(
      msg.value >= _productCostWei,
      'not enough ETH sent to pay for product'
    );
    address payable _paymentWallet = paymentWallet == DEAD_WALLET ||
      paymentWallet == address(0)
      ? payable(owner())
      : paymentWallet;
    _paymentWallet.call{ value: _productCostWei }('');
    _refundExcessPayment(_productCostWei);
    totalSpentWei += _productCostWei;
    emit Spend(msg.sender, _payor, _productCostWei);
  }

  function _refundExcessPayment(uint256 _productCost) internal {
    uint256 excess = msg.value - _productCost;
    if (excess > 0) {
      payable(msg.sender).call{ value: excess }('');
    }
  }
}
