// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import '../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol';
import '../node_modules/@openzeppelin/contracts/access/Ownable.sol';
import './MTGYFaaS.sol';

/**
 * @title MTGYFaaSToken (sMTGY)
 * @author Lance Whatley
 * @notice Represents a contract where a token owner has put her tokens up for others to stake and earn said tokens.
 */
contract MTGYFaaSToken is ERC20, Ownable {
  using SafeMath for uint256;

  address public creator;
  address public tokenOwner;
  uint256 public origTotSupply;
  uint256 public curSupp;
  address public tokenAddress;
  uint256 public totalTokensStaked;
  uint256 public creationBlock;
  uint256 public perBlockNum;
  uint256 public lockedUntilDate;
  bool public contractIsRemoved = false;

  MTGYFaaS private _parentContr;
  ERC20 private _token;
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
   * @param _tokenAddy The token address for the staking contract
   * @param _supply The amount of tokens to mint on construction, this should be the same as the tokens provided by the creating user.
   */
  constructor(
    string memory _name,
    string memory _symbol,
    uint256 _supply,
    address _tokenAddy,
    address _originalTokenOwner,
    uint256 _perBlockAmount,
    uint256 _lockedUntilDate
  ) ERC20(_name, _symbol) {
    require(
      _perBlockAmount > uint256(0) && _perBlockAmount <= uint256(_supply),
      'per block amount must be more than 0 and less than supply'
    );

    // A locked date of '0' corresponds to being locked forever until the supply has expired and been rewards to all stakers
    require(
      _lockedUntilDate > block.timestamp || _lockedUntilDate == 0,
      'locked time must be after now or 0'
    );

    creationBlock = block.number;
    creator = msg.sender;
    origTotSupply = _supply;
    curSupp = _supply;
    tokenOwner = _originalTokenOwner;
    tokenAddress = _tokenAddy;
    perBlockNum = _perBlockAmount;
    lockedUntilDate = _lockedUntilDate;
    _parentContr = MTGYFaaS(creator);
    _token = ERC20(_tokenAddy);
  }

  function removeStakeableTokens() public {
    require(msg.sender == creator, 'caller must be the contract creator');
    _token.transfer(tokenOwner, curSupp);
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
    require(
      _token.balanceOf(msg.sender) >= _amount,
      'user must have enough tokens to stake said amount'
    );

    _token.transferFrom(msg.sender, address(this), _amount);
    _mint(msg.sender, _amount);
    tokenStakers[msg.sender] = TokenHarvester({
      tokenAddy: address(_token),
      blockOriginallStaked: block.number,
      blockLastHarvested: block.number
    });

    _parentContr.addUserAsStaking(msg.sender);
    if (!_parentContr.doesUserHaveContract(msg.sender, address(this))) {
      _parentContr.addUserToContract(msg.sender, address(this));
    }
    _updNumStaked(_amount, 'add');
  }

  function unstakeTokens(uint256 _amount) public {
    require(
      _amount <= balanceOf(msg.sender),
      'user can only unstake amount they have currently staked or less'
    );

    harvestForUser(msg.sender);
    transferFrom(msg.sender, _burner, _amount);
    require(
      _token.transfer(msg.sender, _amount),
      'unable to send user original tokens'
    );
    if (balanceOf(msg.sender) <= 0) {
      _parentContr.removeUserAsStaking(msg.sender);
      _parentContr.removeContractFromUser(msg.sender, address(this));
      delete tokenStakers[msg.sender];
    }

    _updNumStaked(_amount, 'remove');
  }

  function harvestTokens() public returns (uint256) {
    return _harvestTokens(msg.sender);
  }

  function harvestForUser(address _userAddy) public returns (uint256) {
    require(
      msg.sender == creator || msg.sender == address(this),
      'can only harvest tokens for someone else if this was the contract creator'
    );
    return _harvestTokens(_userAddy);
  }

  function getLastStakableBlock() public view returns (uint256) {
    return (origTotSupply.div(perBlockNum)).add(creationBlock);
  }

  function calcHarvestTot(address _userAddy) public view returns (uint256) {
    TokenHarvester memory _staker = tokenStakers[_userAddy];
    uint256 _stBlockInd = 0;

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

      if (_block >= _nextTotal.blockNumber) {
        if (_stBlockInd + 1 < blockTotals.length) {
          _startTotal = blockTotals[_stBlockInd + 1];
          _stBlockInd++;
        }
      }

      if (_startTotal.totalTokens > 0) {
        _tokensToHarvest +=
          perBlockNum *
          (balanceOf(_userAddy) / _startTotal.totalTokens);
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
    require(
      _token.transfer(_userAddy, _num2Trans),
      'unable to send user their harvested tokens'
    );
    curSupp = curSupp.sub(_num2Trans);
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
