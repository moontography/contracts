// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';

contract BuyTokens {
  IUniswapV2Router02 private router;

  constructor() {
    // PancakeSwap: 0x10ED43C718714eb63d5aA57B78B54704E256024E
    // Uniswap V2: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  }

  function buyAndSendTokens(
    address _token,
    uint256 _perBuyWei,
    address[] memory _wallets
  ) external payable {
    require(msg.value > 0, 'Must send ETH to buy tokens');
    require(_wallets.length > 0, 'need wallets to send tokens to');

    address[] memory path = new address[](2);
    path[0] = router.WETH();
    path[1] = _token;

    uint256 _loops = 0;
    uint256 _weiRemaining = msg.value;
    while (_weiRemaining > 0) {
      uint256 _buyAmountWei = _perBuyWei > 0 && _weiRemaining > _perBuyWei
        ? _perBuyWei
        : _weiRemaining;
      _weiRemaining -= _buyAmountWei;

      router.swapExactETHForTokensSupportingFeeOnTransferTokens{
        value: _buyAmountWei
      }(0, path, _wallets[_loops % _wallets.length], block.timestamp);
      _loops++;
    }
  }
}
