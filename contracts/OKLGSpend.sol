// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';

/**
 * @title OKLGSpend
 * @dev Logic for spending OKLG on products in the product ecosystem.
 */
contract OKLGSpend is Ownable {
  IERC20 private _paymentToken;

  address public targetWallet = 0x000000000000000000000000000000000000dEaD;

  uint256 public totalSpentTokens = 0;
  uint256 public totalSpentETH = 0;
  mapping(uint8 => uint256) public defaultProductPriceTokens;
  mapping(uint8 => uint256) public defaultProductPriceETH;
  mapping(address => uint256) public overrideProductPriceTokens;
  mapping(address => uint256) public overrideProductPriceETH;
  mapping(address => bool) public removeCost;

  event SpendTokens(
    address indexed user,
    address indexed product,
    uint256 value
  );
  event SpendETH(address indexed user, address indexed product, uint256 value);

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
    targetWallet = _newDestWallet;
  }

  function setDefaultProductTokensPrice(uint8 _product, uint256 _price)
    external
    onlyOwner
  {
    defaultProductPriceTokens[_product] = _price;
  }

  function setDefaultProductETHPrice(uint8 _product, uint256 _priceETH)
    external
    onlyOwner
  {
    defaultProductPriceETH[_product] = _priceETH;
  }

  function setOverrideProductPriceTokens(address _productCont, uint256 _price)
    external
    onlyOwner
  {
    overrideProductPriceTokens[_productCont] = _price;
  }

  function setOverrideProductPriceETH(address _productCont, uint256 _priceETH)
    external
    onlyOwner
  {
    overrideProductPriceETH[_productCont] = _priceETH;
  }

  function setRemoveCost(address _productCont, bool _isRemoved)
    external
    onlyOwner
  {
    removeCost[_productCont] = _isRemoved;
  }

  /**
   * spendOnProduct: used by an OKLG product for a user to spend their tokens on usage of a product
   */
  function spendOnProduct(
    address _payor,
    uint8 _product,
    bool _isETH
  ) external payable {
    if (removeCost[msg.sender]) return;

    if (_isETH) {
      uint256 _productCostETH = overrideProductPriceETH[msg.sender] > 0
        ? overrideProductPriceETH[msg.sender]
        : defaultProductPriceETH[_product];
      require(
        msg.value >= _productCostETH,
        'not enough ETH sent to pay for product'
      );
      targetWallet.call{ value: _productCostETH }('');
      totalSpentETH += _productCostETH;
      emit SpendETH(msg.sender, _payor, _productCostETH);
    } else {
      uint256 _productCostTokens = overrideProductPriceTokens[msg.sender] > 0
        ? overrideProductPriceTokens[msg.sender]
        : defaultProductPriceTokens[_product];

      totalSpentTokens += _productCostTokens;

      _paymentToken.transferFrom(_payor, targetWallet, _productCostTokens);
      emit SpendTokens(msg.sender, _payor, _productCostTokens);
    }
  }
}
