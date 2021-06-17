// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import '../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol';
import './MTGYFaaS.sol';

/**
 * @title MTGYFaaSToken (sMTGY)
 * @author Lance Whatley
 * @notice Represents a contract where a token owner has put her tokens up for others to stake and earn said tokens.
 */
contract MTGYFaaSToken is ERC20 {
  using SafeMath for uint256;

  address public creator;
  address public tokenOwner;
  uint256 public origTotSupply;
  uint256 public curRewardsSupply;
  address public rewardsTokenAddress;
  address public stakedTokenAddress;
  uint256 public totalTokensStaked;
  uint256 public creationBlock;
  uint256 public perBlockNum;
  uint256 public lockedUntilDate;
  bool public contractIsRemoved = false;

  MTGYFaaS private _parentContract;
  ERC20 private _rewardsToken;
  ERC20 private _stakedToken;
  address private constant _burner = 0x000000000000000000000000000000000000dEaD;

  struct TokenHarvester {
    address tokenAddy;
    uint256 blockOriginallStaked;
    uint256 blockLastHarvested;
  }

  struct BlockTokenTotal {
    uint256 blockNumber;
    uint256 totalTokens;
  }

  // mapping of userAddresses => tokenAddresses that can
  // can be evaluated to determine for a particular user which tokens
  // they are staking.
  mapping(address => TokenHarvester) public tokenStakers;

  BlockTokenTotal[] public blockTotals;

  /**
   * @notice The constructor for the Staking Token.
   * @param _name Name of the staking token
   * @param _symbol Name of the staking token symbol
   * @param _rewardSupply The amount of tokens to mint on construction, this should be the same as the tokens provided by the creating user.
   * @param _rewardsTokenAddy Contract address of token to be rewarded to users
   * @param _stakedTokenAddy Contract address of token to be staked by users
   * @param _originalTokenOwner Address of user putting up staking tokens to be staked
   * @param _perBlockAmount Amount of tokens to be rewarded per block
   * @param _lockedUntilDate Unix timestamp that the staked tokens will be locked. 0 means locked forever until all tokens are staked
   */
  constructor(
    string memory _name,
    string memory _symbol,
    uint256 _rewardSupply,
    address _rewardsTokenAddy,
    address _stakedTokenAddy,
    address _originalTokenOwner,
    uint256 _perBlockAmount,
    uint256 _lockedUntilDate
  ) ERC20(_name, _symbol) {
    require(
      _perBlockAmount > uint256(0) && _perBlockAmount <= uint256(_rewardSupply),
      'per block amount must be more than 0 and less than supply'
    );

    // A locked date of '0' corresponds to being locked forever until the supply has expired and been rewards to all stakers
    require(
      _lockedUntilDate > block.timestamp || _lockedUntilDate == 0,
      'locked time must be after now or 0'
    );

    creationBlock = block.number;
    creator = msg.sender;
    origTotSupply = _rewardSupply;
    curRewardsSupply = _rewardSupply;
    tokenOwner = _originalTokenOwner;
    rewardsTokenAddress = _rewardsTokenAddy;
    stakedTokenAddress = _stakedTokenAddy;
    perBlockNum = _perBlockAmount;
    lockedUntilDate = _lockedUntilDate;
    _parentContract = MTGYFaaS(creator);
    _rewardsToken = ERC20(_rewardsTokenAddy);
    _stakedToken = ERC20(_stakedTokenAddy);
  }

  function removeStakeableTokens() public {
    require(msg.sender == creator, 'caller must be the contract creator');
    _rewardsToken.transfer(tokenOwner, curRewardsSupply);
    contractIsRemoved = true;
  }

  function updatePerBlockAmount(uint256 _amount) public {
    require(
      msg.sender == tokenOwner,
      'updatePerBlockAmount user must be original token owner'
    );
    perBlockNum = _amount;
  }

  function updateTimestamp(uint256 _newTime) public {
    require(
      msg.sender == tokenOwner,
      'updateTimestamp user must be original token owner'
    );
    require(
      _newTime > lockedUntilDate || _newTime == 0,
      'you cannot change timestamp if it is before the locked time or was set to be locked forever'
    );
    lockedUntilDate = _newTime;
  }

  function stakeTokens(uint256 _amount) public {
    _stakedToken.transferFrom(msg.sender, address(this), _amount);
    if (totalSupply() == 0) {
      creationBlock = block.number;
    }
    _mint(msg.sender, _amount);
    tokenStakers[msg.sender] = TokenHarvester({
      tokenAddy: address(_stakedToken),
      blockOriginallStaked: block.number,
      blockLastHarvested: block.number
    });

    _parentContract.addUserAsStaking(msg.sender);
    if (!_parentContract.doesUserHaveContract(msg.sender, address(this))) {
      _parentContract.addUserToContract(msg.sender, address(this));
    }
    _updNumStaked(_amount, 'add');
  }

  function unstakeTokens(uint256 _amount) public {
    require(
      _amount <= balanceOf(msg.sender),
      'user can only unstake amount they have currently staked or less'
    );

    harvestForUser(msg.sender);
    transfer(_burner, _amount);
    require(
      _stakedToken.transfer(msg.sender, _amount),
      'unable to send user original tokens'
    );
    if (balanceOf(msg.sender) <= 0) {
      _parentContract.removeUserAsStaking(msg.sender);
      _parentContract.removeContractFromUser(msg.sender, address(this));
      delete tokenStakers[msg.sender];
    }

    _updNumStaked(_amount, 'remove');
  }

  function harvestTokens() public returns (uint256) {
    return _harvestTokens(msg.sender);
  }

  function harvestForUser(address _userAddy) public returns (uint256) {
    require(
      msg.sender == creator || msg.sender == _userAddy,
      'can only harvest tokens for someone else if this was the contract creator'
    );
    return _harvestTokens(_userAddy);
  }

  function getLastStakableBlock() public view returns (uint256) {
    return (origTotSupply.div(perBlockNum)).add(creationBlock);
  }

  function calcHarvestTot(address _userAddy) public view returns (uint256) {
    TokenHarvester memory _staker = tokenStakers[_userAddy];

    // get the appropriate first index for the blockTotals we're checking
    // based on when the user last harvested tokens.
    uint256 _stBlockInd = 0;
    while (blockTotals[_stBlockInd].blockNumber < _staker.blockLastHarvested) {
      if (
        _stBlockInd + 1 < blockTotals.length &&
        blockTotals[_stBlockInd + 1].blockNumber < _staker.blockLastHarvested
      ) {
        _stBlockInd++;
      } else {
        break;
      }
    }

    if (_staker.blockLastHarvested == block.number) {
      return uint256(0);
    }

    uint256 _lastBl = block.number;
    uint256 _absLastBlock = getLastStakableBlock();
    if (_absLastBlock < _lastBl) {
      _lastBl = _absLastBlock;
    }

    uint256 _tokensToHarvest = 0;
    BlockTokenTotal memory _startTotal = blockTotals[_stBlockInd];
    for (
      uint256 _block = _staker.blockLastHarvested;
      _block < _lastBl;
      _block++
    ) {
      BlockTokenTotal memory _nextTotal = blockTotals[_stBlockInd];
      if (_stBlockInd + 1 < blockTotals.length) {
        _nextTotal = blockTotals[_stBlockInd + 1];
      }

      if (
        _block >= _nextTotal.blockNumber &&
        _startTotal.blockNumber != _nextTotal.blockNumber
      ) {
        if (_stBlockInd + 1 < blockTotals.length) {
          _startTotal = blockTotals[_stBlockInd + 1];
          _stBlockInd++;
        }
      }

      if (_startTotal.totalTokens > 0) {
        // Solidity division is integer division, so you can't divide by a larger number
        // and get anything other than 0. Need to do multiplication first then
        // divide by the total.
        // _tokensToHarvest += perBlockNum.mul(
        //   balanceOf(_userAddy).div(_startTotal.totalTokens)
        // );
        _tokensToHarvest += balanceOf(_userAddy).mul(perBlockNum).div(
          _startTotal.totalTokens
        );
      }
    }
    return _tokensToHarvest;
  }

  function _harvestTokens(address _userAddy) private returns (uint256) {
    TokenHarvester memory _num = tokenStakers[_userAddy];
    require(_num.blockOriginallStaked > 0, 'user must have tokens staked');

    uint256 _diff = block.number - _num.blockLastHarvested;
    require(_diff >= 0, 'must be after when the user last harvested');

    uint256 _num2Trans = calcHarvestTot(_userAddy);
    if (_num2Trans > 0) {
      require(
        _rewardsToken.transfer(_userAddy, _num2Trans),
        'unable to send user their harvested tokens'
      );
      curRewardsSupply = curRewardsSupply.sub(_num2Trans);
    }
    tokenStakers[_userAddy].blockLastHarvested = block.number;
    return _num2Trans;
  }

  // update the amount currently staked after a user harvests
  function _updNumStaked(uint256 _amount, string memory _operation) private {
    if (_compareStr(_operation, 'remove')) {
      totalTokensStaked = totalTokensStaked - _amount;
    } else {
      totalTokensStaked = totalTokensStaked + _amount;
    }

    BlockTokenTotal memory newBlockTotal =
      BlockTokenTotal({
        blockNumber: block.number,
        totalTokens: totalTokensStaked
      });
    blockTotals.push(newBlockTotal);
  }

  function _compareStr(string memory a, string memory b)
    private
    pure
    returns (bool)
  {
    return (keccak256(abi.encodePacked((a))) ==
      keccak256(abi.encodePacked((b))));
  }
}
