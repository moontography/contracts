// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import './OKLGWithdrawable.sol';

contract OKLGDividendDistributor is OKLGWithdrawable {
  using SafeMath for uint256;

  struct Share {
    uint256 totalExcluded; // excluded dividend
    uint256 totalRealised;
  }

  address public shareholderToken;
  uint256 totalShares;
  address wrappedNative;
  IUniswapV2Router02 router;

  // used to fetch in a frontend to get full list
  // of tokens that dividends can be claimed
  address[] public tokens;
  mapping(address => bool) tokenAwareness;

  address[] shareholders;
  mapping(address => uint256) shareholderClaims;

  mapping(address => mapping(address => Share)) public shares;

  mapping(address => uint256) public totalDividends;
  mapping(address => uint256) public totalDistributed; // to be shown in UI
  mapping(address => uint256) public dividendsPerShare;
  uint256 public dividendsAccFactor = 10**36;

  constructor(
    address _dexRouter,
    address _shareholderToken,
    address _wrappedNative
  ) {
    router = IUniswapV2Router02(_dexRouter);
    shareholderToken = _shareholderToken;
    totalShares = IERC20(shareholderToken).totalSupply();
    wrappedNative = _wrappedNative;
  }

  function getDividendTokens() external view returns (address[] memory) {
    return tokens;
  }

  // tokenAddress == address(0) means native token
  // any other token should be ERC20 listed on DEX router provided in constructor
  function deposit(address tokenAddress, uint256 erc20DirectAmount)
    external
    payable
  {
    require(
      erc20DirectAmount > 0 || msg.value > 0,
      'value must be greater than 0'
    );

    if (!tokenAwareness[tokenAddress]) {
      tokenAwareness[tokenAddress] = true;
      tokens.push(tokenAddress);
    }

    IERC20 token;
    uint256 amount;
    if (tokenAddress == address(0)) {
      payable(address(this)).call{ value: msg.value }('');
      amount = msg.value;
    } else if (erc20DirectAmount > 0) {
      IERC20(tokenAddress).transferFrom(
        msg.sender,
        address(this),
        erc20DirectAmount
      );
      amount = erc20DirectAmount;
    } else {
      token = IERC20(tokenAddress);

      uint256 balanceBefore = token.balanceOf(address(this));

      address[] memory path = new address[](2);
      path[0] = wrappedNative;
      path[1] = tokenAddress;

      router.swapExactETHForTokensSupportingFeeOnTransferTokens{
        value: msg.value
      }(0, path, address(this), block.timestamp);

      amount = token.balanceOf(address(this)).sub(balanceBefore);
    }

    totalDividends[tokenAddress] = totalDividends[tokenAddress].add(amount);
    dividendsPerShare[tokenAddress] = dividendsPerShare[tokenAddress].add(
      dividendsAccFactor.mul(amount).div(totalShares)
    );
  }

  function distributeDividend(
    address token,
    address shareholder,
    bool compound
  ) internal {
    uint256 shareholderAmount = IERC20(shareholderToken).balanceOf(shareholder);
    if (shareholderAmount == 0) {
      return;
    }

    uint256 amount = getUnpaidEarnings(token, shareholder);
    if (amount > 0) {
      totalDistributed[token] = totalDistributed[token].add(amount);
      // native transfer
      if (token == address(0)) {
        if (compound) {
          address[] memory path = new address[](2);
          path[0] = wrappedNative;
          path[1] = shareholderToken;
          router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amount
          }(0, path, shareholder, block.timestamp);
        } else {
          payable(shareholder).call{ value: amount }('');
        }
      } else {
        IERC20(token).transfer(shareholder, amount);
      }
      shareholderClaims[shareholder] = block.timestamp;
      shares[shareholder][token].totalRealised = shares[shareholder][token]
        .totalRealised
        .add(amount);
      shares[shareholder][token].totalExcluded = getCumulativeDividends(
        token,
        shareholderAmount
      );
    }
  }

  function claimDividend(address token, bool compound) external {
    distributeDividend(token, msg.sender, compound);
  }

  /*
returns the  unpaid earnings
*/
  function getUnpaidEarnings(address token, address shareholder)
    public
    view
    returns (uint256)
  {
    uint256 shareholderAmount = IERC20(shareholderToken).balanceOf(shareholder);
    if (shareholderAmount == 0) {
      return 0;
    }

    uint256 shareholderTotalDividends = getCumulativeDividends(
      token,
      shareholderAmount
    );
    uint256 shareholderTotalExcluded = shares[shareholder][token].totalExcluded;

    if (shareholderTotalDividends <= shareholderTotalExcluded) {
      return 0;
    }

    return shareholderTotalDividends.sub(shareholderTotalExcluded);
  }

  function getCumulativeDividends(address token, uint256 share)
    internal
    view
    returns (uint256)
  {
    return share.mul(dividendsPerShare[token]).div(dividendsAccFactor);
  }

  function setShareholderToken(address _token) external onlyOwner {
    shareholderToken = _token;
    totalShares = IERC20(shareholderToken).totalSupply();
  }

  receive() external payable {}
}
