// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import './interfaces/IDividendDistributor.sol';
import './OKLGWithdrawable.sol';

contract OKLGDividendDistributor is IDividendDistributor, OKLGWithdrawable {
  using SafeMath for uint256;

  struct Share {
    uint256 amount;
    uint256 totalExcluded; // excluded dividend
    uint256 totalRealised;
  }

  address wrappedNative;
  IUniswapV2Router02 router;

  address[] public tokens;
  mapping(address => bool) tokenAwareness;

  address[] shareholders;
  mapping(address => uint256) shareholderIndexes;
  mapping(address => uint256) shareholderClaims;

  mapping(address => mapping(address => Share)) public shares;

  mapping(address => uint256) public totalShares;
  mapping(address => uint256) public totalDividends;
  mapping(address => uint256) public totalDistributed; // to be shown in UI
  mapping(address => uint256) public dividendsPerShare;
  uint256 public dividendsAccFactor = 10**36;

  uint256 public minPeriod = 12 hours;
  uint256 public minDistribution = 10 * (10**18);

  constructor(address _dexRouter, address _wrappedNative) {
    router = IUniswapV2Router02(_dexRouter);
    wrappedNative = _wrappedNative;
  }

  function getDividendTokens() external view returns (address[] memory) {
    return tokens;
  }

  function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution)
    external
    override
    onlyOwner
  {
    minPeriod = _minPeriod;
    minDistribution = _minDistribution;
  }

  function setShare(
    address token,
    address shareholder,
    uint256 amount
  ) external override onlyOwner {
    if (shares[shareholder][token].amount > 0) {
      distributeDividend(token, shareholder, false);
    }

    if (amount > 0 && shares[shareholder][token].amount == 0) {
      addShareholder(shareholder);
    } else if (amount == 0 && shares[shareholder][token].amount > 0) {
      removeShareholder(shareholder);
    }

    if (!tokenAwareness[token]) {
      tokenAwareness[token] = true;
      tokens.push(token);
    }
    totalShares[token] = totalShares[token]
      .sub(shares[shareholder][token].amount)
      .add(amount);
    shares[shareholder][token].amount = amount;
    shares[shareholder][token].totalExcluded = getCumulativeDividends(
      token,
      shares[shareholder][token].amount
    );
  }

  // tokenAddress == address(0) means native token
  // any other token should be ERC20 listed on DEX router provided in constructor
  function deposit(address tokenAddress, uint256 erc20DirectAmount)
    external
    payable
    override
  {
    require(
      erc20DirectAmount > 0 || msg.value > 0,
      'value must be greater than 0'
    );

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
      dividendsAccFactor.mul(amount).div(totalShares[tokenAddress])
    );
  }

  function distributeDividend(
    address token,
    address shareholder,
    bool compound
  ) internal {
    if (shares[shareholder][token].amount == 0) {
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
          path[1] = token;
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
        shares[shareholder][token].amount
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
    if (shares[shareholder][token].amount == 0) {
      return 0;
    }

    uint256 shareholderTotalDividends = getCumulativeDividends(
      token,
      shares[shareholder][token].amount
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

  function addShareholder(address shareholder) internal {
    shareholderIndexes[shareholder] = shareholders.length;
    shareholders.push(shareholder);
  }

  function removeShareholder(address shareholder) internal {
    shareholders[shareholderIndexes[shareholder]] = shareholders[
      shareholders.length - 1
    ];
    shareholderIndexes[
      shareholders[shareholders.length - 1]
    ] = shareholderIndexes[shareholder];
    shareholders.pop();
  }

  receive() external payable {}
}
