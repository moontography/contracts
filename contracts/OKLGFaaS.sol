// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';
import './OKLGFaaSToken.sol';
import './OKLGProduct.sol';

/**
 * @title OKLGFaaS (sOKLG)
 * @author Lance Whatley
 * @notice Implements the master FaaS contract to keep track of all tokens being added
 * to be staked and staking.
 */
contract OKLGFaaS is OKLGProduct {
  // this is a mapping of tokenAddress => contractAddress[] that represents
  // a particular address for the token that someone has put up
  // to be staked and a list of contract addresses for the staking token
  // contracts paying out stakers for the given token.
  mapping(address => address[]) public tokensUpForStaking;
  address[] public allFarmingContracts;
  uint256 public totalStakingContracts;

  AggregatorV3Interface internal priceFeed;

  uint256 public timePeriodDays = 30; // don't convert to seconds because we calc against blocksPerDay below
  uint256 public priceUSDPerTimePeriod18 = 250 * 10**18;
  uint256 public blocksPerDay;

  /**
   * @notice The constructor for the staking master contract.
   */
  constructor(
    address _tokenAddress,
    address _spendAddress,
    address _linkPriceFeedContract,
    uint256 _blocksPerDay
  ) OKLGProduct(uint8(8), _tokenAddress, _spendAddress) {
    // https://docs.chain.link/docs/reference-contracts/
    // https://github.com/pcaversaccio/chainlink-price-feed/blob/main/README.md
    priceFeed = AggregatorV3Interface(_linkPriceFeedContract);
    blocksPerDay = _blocksPerDay;
  }

  function getAllFarmingContracts() external view returns (address[] memory) {
    return allFarmingContracts;
  }

  function getTokensForStaking(address _tokenAddress)
    external
    view
    returns (address[] memory)
  {
    return tokensUpForStaking[_tokenAddress];
  }

  function _payForPool(uint256 _tokenSupply, uint256 _perBlockAllocation)
    internal
  {
    uint256 _blockLifespan = _tokenSupply / _perBlockAllocation;
    uint256 _costUSD18 = (priceUSDPerTimePeriod18 * _blockLifespan) /
      timePeriodDays /
      blocksPerDay;
    uint256 _costWei = _getProductCostWei(_costUSD18);
    require(msg.value >= _costWei, 'not enough ETH to pay for service');
    payable(owner()).call{ value: msg.value }('');
  }

  function _getProductCostWei(uint256 _productCostUSD18)
    internal
    view
    returns (uint256)
  {
    // adding back 18 decimals to get returned value in wei
    return (10**18 * _productCostUSD18) / _getLatestETHPrice();
  }

  /**
   * Returns the latest ETH/USD price with returned value at 18 decimals
   * https://docs.chain.link/docs/get-the-latest-price/
   */
  function _getLatestETHPrice() internal view returns (uint256) {
    uint8 decimals = priceFeed.decimals();
    (, int256 price, , , ) = priceFeed.latestRoundData();
    return uint256(price) * (10**18 / 10**decimals);
  }

  function createNewTokenContract(
    address _rewardsTokenAddy,
    address _stakedTokenAddy,
    uint256 _supply,
    uint256 _perBlockAllocation,
    uint256 _lockedUntilDate,
    uint256 _timelockSeconds,
    bool _isStakedNft
  ) external payable {
    _payForPool(_supply, _perBlockAllocation);

    // create new OKLGFaaSToken contract which will serve as the core place for
    // users to stake their tokens and earn rewards
    ERC20 _rewToken = ERC20(_rewardsTokenAddy);

    // Send the new contract all the tokens from the sending user to be staked and harvested
    _rewToken.transferFrom(msg.sender, address(this), _supply);

    // in order to handle tokens that take tax, are burned, etc. when transferring, need to get
    // the user's balance after transferring in order to send the remainder of the tokens
    // instead of the full original supply. Similar to slippage on a DEX
    uint256 _updatedSupply = _supply <= _rewToken.balanceOf(address(this))
      ? _supply
      : _rewToken.balanceOf(address(this));

    OKLGFaaSToken _contract = new OKLGFaaSToken(
      'OKLG Staking Token',
      'sOKLG',
      _updatedSupply,
      _rewardsTokenAddy,
      _stakedTokenAddy,
      msg.sender,
      _perBlockAllocation,
      _lockedUntilDate,
      _timelockSeconds,
      _isStakedNft
    );
    allFarmingContracts.push(address(_contract));
    tokensUpForStaking[_stakedTokenAddy].push(address(_contract));
    totalStakingContracts++;

    _rewToken.transfer(address(_contract), _updatedSupply);

    // do one more double check on balance of rewards token
    // in the staking contract and update if need be
    uint256 _finalSupply = _updatedSupply <=
      _rewToken.balanceOf(address(_contract))
      ? _updatedSupply
      : _rewToken.balanceOf(address(_contract));
    if (_updatedSupply != _finalSupply) {
      _contract.updateSupply(_finalSupply);
    }
  }

  function removeTokenContract(address _faasTokenAddy) external {
    OKLGFaaSToken _contract = OKLGFaaSToken(_faasTokenAddy);
    require(
      msg.sender == _contract.tokenOwner(),
      'user must be the original token owner to remove tokens'
    );
    require(
      block.timestamp > _contract.getLockedUntilDate() &&
        _contract.getLockedUntilDate() != 0,
      'it must be after the locked time the user originally configured and not locked forever'
    );

    _contract.removeStakeableTokens();
    totalStakingContracts--;
  }

  function setTimePeriodDays(uint256 _days) external onlyOwner {
    timePeriodDays = _days;
  }

  function setPriceUSDPerTimePeriod18(uint256 _priceUSD18) external onlyOwner {
    priceUSDPerTimePeriod18 = _priceUSD18;
  }

  function setBlocksPerDay(uint256 _blocks) external onlyOwner {
    blocksPerDay = _blocks;
  }
}
