// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '../OKLGWithdrawable.sol';

contract HoneypotCheck is OKLGWithdrawable {
  IUniswapV2Router02 private router;

  constructor() {
    // PancakeSwap: 0x10ED43C718714eb63d5aA57B78B54704E256024E
    // Uniswap V2: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  }

  function buyThenSellNoSlippage(address token) external payable {
    require(msg.value > 0, 'Must send ETH to buy token');

    // buy
    address[] memory buyPath = new address[](2);
    buyPath[0] = router.WETH();
    buyPath[1] = token;
    router.swapExactETHForTokensSupportingFeeOnTransferTokens{
      value: msg.value
    }(
      0, // not accounting for slippage
      buyPath,
      address(this),
      block.timestamp
    );

    // sell
    IERC20 tokenContract = IERC20(token);
    uint256 currentBalance = tokenContract.balanceOf(address(this));
    address[] memory sellPath = new address[](2);
    sellPath[0] = token;
    sellPath[1] = router.WETH();
    tokenContract.approve(address(router), currentBalance);

    router.swapExactTokensForETHSupportingFeeOnTransferTokens(
      currentBalance,
      0, // not accounting for slippage
      sellPath,
      address(this),
      block.timestamp
    );
  }

  // 0 <= slippage <= 100
  function buyThenSellWithSlippage(address token, uint16 slippage)
    external
    payable
  {
    require(msg.value > 0, 'Must send ETH to buy token');
    require(slippage <= 100, 'slippage cannot be more than 100%');

    address pair = IUniswapV2Factory(router.factory()).getPair(
      router.WETH(),
      token
    );

    (uint112 _r01, uint112 _r11, ) = IUniswapV2Pair(pair).getReserves();
    uint256 amountTokensToReceiveNoSlip = 0;
    if (IUniswapV2Pair(pair).token0() == router.WETH()) {
      amountTokensToReceiveNoSlip = (msg.value * _r11) / _r01;
    } else {
      amountTokensToReceiveNoSlip = (msg.value * _r01) / _r11;
    }

    // buy
    address[] memory buyPath = new address[](2);
    buyPath[0] = router.WETH();
    buyPath[1] = token;
    router.swapExactETHForTokensSupportingFeeOnTransferTokens{
      value: msg.value
    }(
      (amountTokensToReceiveNoSlip * (100 - slippage)) / 100,
      buyPath,
      address(this),
      block.timestamp
    );

    // sell
    uint256 currentBalance = IERC20(token).balanceOf(address(this));

    (uint112 _r02, uint112 _r12, ) = IUniswapV2Pair(pair).getReserves();
    uint256 amountETHToReceiveNoSlip = 0;
    if (IUniswapV2Pair(pair).token0() == router.WETH()) {
      amountETHToReceiveNoSlip = (currentBalance * _r02) / _r12;
    } else {
      amountETHToReceiveNoSlip = (currentBalance * _r12) / _r02;
    }

    address[] memory sellPath = new address[](2);
    sellPath[0] = token;
    sellPath[1] = router.WETH();
    IERC20(token).approve(address(router), currentBalance);

    router.swapExactTokensForETHSupportingFeeOnTransferTokens(
      currentBalance,
      (amountETHToReceiveNoSlip * (100 - slippage)) / 100,
      sellPath,
      address(this),
      block.timestamp
    );
  }

  receive() external payable {}
}
