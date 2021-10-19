// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC721.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import './MTGYSpend.sol';

/**
 * @title MTGYTokenLocker
 * @dev This is the main contract that supports locking/vesting tokens.
 */
contract MTGYTokenLocker is Ownable {
  using SafeMath for uint256;

  struct Locker {
    address owner;
    bool isNft; // rewardToken is either ERC20 or ERC721
    address token;
    uint256 amountSupply; // If ERC-721, will always be 1, otherwise is amount of tokens locked
    uint256 tokenId; // only populated if isNft is true
    uint256 start; // timestamp (uint256) of start lock time (block.timestamp at creation)
    uint256 end; // timestamp (uint256) of end lock time
    address[] withdrawable; // any additional addresses that can withdraw tokens from this locker
    uint256 amountWithdrawn;
    // numberVests:
    // 1 means can only withdraw tokens at end of lock period
    // any other number is evenly distributed throughout lock period
    uint256 numberVests;
  }

  IERC20 private _mtgy;
  MTGYSpend private _spend;

  uint256 public mtgyServiceCost = 5000 * 10**18;

  mapping(address => uint256[]) public lockersByOwner;
  mapping(address => uint256[]) public lockersByToken;
  mapping(address => uint256[]) public lockersByWithdrawable;
  Locker[] public lockers;

  event CreateLocker(address indexed creator, uint256 idx);
  event WithdrawTokens(
    uint256 indexed idx,
    address withdrawer,
    uint256 numTokensOrTokenId
  );

  constructor(address _mtgyAddress, address _mtgySpendAddress) {
    _mtgy = IERC20(_mtgyAddress);
    _spend = MTGYSpend(_mtgySpendAddress);
  }

  function getAllLockers() external view returns (Locker[] memory) {
    return lockers;
  }

  function createLocker(
    address _tokenAddress,
    uint256 _amountOrTokenId,
    uint256 _end,
    uint256 _numberVests,
    address[] memory _withdrawableAddresses,
    bool _isNft
  ) external {
    require(
      _end > block.timestamp,
      'Locker end date must be after current time.'
    );

    if (mtgyServiceCost > 0) {
      _mtgy.transferFrom(msg.sender, address(this), mtgyServiceCost);
      _mtgy.approve(address(_spend), mtgyServiceCost);
      _spend.spendOnProduct(mtgyServiceCost);
    }

    if (_isNft) {
      IERC721 _token = IERC721(_tokenAddress);
      _token.transferFrom(msg.sender, address(this), _amountOrTokenId);
    } else {
      IERC20 _token = IERC20(_tokenAddress);
      _token.transferFrom(msg.sender, address(this), _amountOrTokenId);
    }

    lockers.push(
      Locker({
        owner: msg.sender,
        isNft: _isNft,
        token: _tokenAddress,
        amountSupply: _isNft ? 1 : _amountOrTokenId,
        tokenId: _isNft ? _amountOrTokenId : 0,
        start: block.timestamp,
        end: _end,
        withdrawable: _withdrawableAddresses,
        amountWithdrawn: 0,
        numberVests: _isNft ? 1 : (_numberVests == 0 ? 1 : _numberVests)
      })
    );
    uint256 _newIdx = lockers.length - 1;
    lockersByOwner[msg.sender].push(_newIdx);
    lockersByToken[_tokenAddress].push(_newIdx);
    if (_withdrawableAddresses.length > 0) {
      for (uint256 _i = 0; _i < _withdrawableAddresses.length; _i++) {
        lockersByWithdrawable[_withdrawableAddresses[_i]].push(_newIdx);
      }
    }
    emit CreateLocker(msg.sender, _newIdx);
  }

  function withdrawLockedTokens(uint256 _idx, uint256 _amountOrTokenId)
    external
  {
    Locker storage _locker = lockers[_idx];
    require(
      _locker.amountWithdrawn < _locker.amountSupply,
      'All tokens have been withdrawn from this locker.'
    );

    bool _canWithdraw = msg.sender == _locker.owner;
    if (!_canWithdraw) {
      for (uint256 _i = 0; _i < _locker.withdrawable.length; _i++) {
        if (_locker.withdrawable[_i] == msg.sender) {
          _canWithdraw = true;
          break;
        }
      }
    }
    require(_canWithdraw, 'Must be locker owner or a withdrawable wallet.');

    if (_locker.isNft) {
      IERC721 _token = IERC721(_locker.token);
      _token.transferFrom(address(this), msg.sender, _amountOrTokenId);
    } else {
      uint256 _maxAmount = maxWithdrawableTokens(_idx);
      require(
        _amountOrTokenId > 0 &&
          _maxAmount > 0 &&
          _maxAmount <= _amountOrTokenId,
        'Make sure you enter a valid withdrawable amount and not more than has vested.'
      );
      IERC20 _token = IERC20(_locker.token);
      _token.transferFrom(address(this), msg.sender, _amountOrTokenId);
    }
    _locker.amountWithdrawn = _locker.isNft ? 1 : _amountOrTokenId;
    emit WithdrawTokens(_idx, msg.sender, _amountOrTokenId);
  }

  function changeLockerOwner(uint256 _idx, address _newOwner) external {
    Locker storage _locker = lockers[_idx];
    require(
      _locker.owner == msg.sender,
      'Must be the locker owner to change owner.'
    );
    _locker.owner = _newOwner;
  }

  function changeLockerEndTime(uint256 _idx, uint256 _newEnd) external {
    Locker storage _locker = lockers[_idx];
    require(
      _locker.owner == msg.sender,
      'Must be the locker owner to change owner.'
    );
    require(_newEnd > _locker.end, 'Can only extend end time, not shorten it.');
    _locker.end = _newEnd;
  }

  function changeMtgyTokenAddy(address _tokenAddy) external onlyOwner {
    _mtgy = IERC20(_tokenAddy);
  }

  function changeSpendAddress(address _spendAddress) external onlyOwner {
    _spend = MTGYSpend(_spendAddress);
  }

  function changeMtgyServiceCost(uint256 _newCost) external onlyOwner {
    mtgyServiceCost = _newCost;
  }

  function maxWithdrawableTokens(uint256 _idx) public returns (uint256) {
    Locker memory _locker = lockers[_idx];
    uint256 _fullLockPeriodSec = _locker.end.sub(_locker.start);
    uint256 _secondsPerVest = _fullLockPeriodSec.div(_locker.numberVests);
    uint256 _tokensPerVest = _locker.amountSupply.div(_locker.numberVests);
    uint256 _numberWithdrawableVests = (block.timestamp.sub(_locker.start)).div(
      _secondsPerVest
    );
    if (_numberWithdrawableVests == 0) return 0;
    return
      _numberWithdrawableVests.mul(_tokensPerVest).sub(_locker.amountWithdrawn);
  }
}
