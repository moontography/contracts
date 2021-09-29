// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import './MTGY.sol';
import './MTGYSpend.sol';

/**
 * @title MTGYRaffle
 * @dev This is the main contract that supports lotteries and raffles.
 */
contract MTGYRaffle is Ownable {
  struct Raffle {
    address owner;
    bool isNft; // ERC20 or ERC721
    address rewardToken;
    uint256 rewardAmountOrTokenId;
    uint256 start;
    uint256 end;
    address entryToken;
    uint256 entryFee;
    uint256 entryFeesCollected;
    address[] entries;
    address winner;
    bool isComplete;
  }

  MTGY private _mtgy;
  MTGYSpend private _spend;

  uint256 public mtgyServiceCost = 5000 * 10**18;
  uint256 public entryFeePercentageCharge = 1;

  mapping(bytes32 => Raffle) public raffles;
  bytes32[] public raffleIds;

  event CreateRaffle(address indexed creator, bytes32 id);
  event EnterRaffle(address indexed raffler, bytes32 id);
  event DrawWinner(bytes32 id, address winner);

  constructor(address _mtgyAddress, address _mtgySpendAddress) {
    _mtgy = MTGY(_mtgyAddress);
    _spend = MTGYSpend(_mtgySpendAddress);
  }

  function createRaffle(
    address _rewardTokenAddress,
    uint256 _rewardAmountOrTokenId,
    bool _isNft,
    uint256 _start,
    uint256 _end,
    address _entryToken,
    uint256 _entryFee
  ) external {
    _mtgy.transferFrom(msg.sender, address(this), mtgyServiceCost);
    _mtgy.approve(address(_spend), mtgyServiceCost);
    _spend.spendOnProduct(mtgyServiceCost);

    if (_isNft) {
      ERC721 _rewardToken = ERC721(_rewardTokenAddress);
      _rewardToken.transferFrom(
        msg.sender,
        address(this),
        _rewardAmountOrTokenId
      );
    } else {
      ERC20 _rewardToken = ERC20(_rewardTokenAddress);
      _rewardToken.transferFrom(
        msg.sender,
        address(this),
        _rewardAmountOrTokenId
      );
    }

    bytes32 _id = sha256(abi.encodePacked(msg.sender, block.number));
    address[] memory _entries;
    raffles[_id] = Raffle({
      owner: msg.sender,
      isNft: _isNft,
      rewardToken: _rewardTokenAddress,
      rewardAmountOrTokenId: _rewardAmountOrTokenId,
      start: _start,
      end: _end,
      entryToken: _entryToken,
      entryFee: _entryFee,
      entryFeesCollected: 0,
      entries: _entries,
      winner: address(0),
      isComplete: false
    });
    raffleIds.push(_id);
    emit CreateRaffle(msg.sender, _id);
  }

  function drawWinner(bytes32 _id) external {
    Raffle storage _raffle = raffles[_id];
    require(
      _raffle.owner == msg.sender,
      'Must be the raffle owner to draw winner'
    );

    if (_raffle.entryFeesCollected > 0) {
      ERC20 _entryToken = ERC20(_raffle.entryToken);
      _entryToken.transfer(_raffle.owner, _raffle.entryFeesCollected);
    }

    uint256 _winnerIdx = _random(_raffle.entries.length) %
      _raffle.entries.length;
    address _winner = _raffle.entries[_winnerIdx];
    _raffle.winner = _winner;

    if (_raffle.isNft) {
      ERC721 _rewardToken = ERC721(_raffle.rewardToken);
      _rewardToken.transferFrom(
        address(this),
        _winner,
        _raffle.rewardAmountOrTokenId
      );
    } else {
      ERC20 _rewardToken = ERC20(_raffle.rewardToken);
      _rewardToken.transfer(_winner, _raffle.rewardAmountOrTokenId);
    }

    _raffle.isComplete = true;
    emit DrawWinner(_id, _winner);
  }

  function enterRaffle(bytes32 _id) external {
    Raffle storage _raffle = raffles[_id];
    require(_raffle.owner != address(0), 'We do not recognize this raffle.');
    require(
      _raffle.start <= block.timestamp,
      'It must be after the start time to enter the raffle.'
    );
    require(
      _raffle.end >= block.timestamp,
      'It must be before the end time to enter the raffle.'
    );
    require(!_raffle.isComplete, 'Faffle cannot be complete to be entered.');

    if (_raffle.entryFee > 0) {
      ERC20 _entryToken = ERC20(_raffle.entryToken);
      _entryToken.transferFrom(msg.sender, address(this), _raffle.entryFee);

      uint256 _feeForRaffle = _raffle.entryFee;
      if (entryFeePercentageCharge > 0) {
        uint256 _feeChargeAmount = (_feeForRaffle * entryFeePercentageCharge) /
          100;
        _entryToken.transfer(owner(), _feeChargeAmount);
        _feeForRaffle -= _feeChargeAmount;
      }
      _raffle.entryFeesCollected += _feeForRaffle;
    }

    _raffle.entries.push(msg.sender);
    emit EnterRaffle(msg.sender, _id);
  }

  function changeRaffleOwner(bytes32 _id, address _newOwner) external {
    Raffle storage _raffle = raffles[_id];
    require(
      _raffle.owner == msg.sender,
      'Must be the raffle owner to change owner'
    );

    _raffle.owner = _newOwner;
  }

  function changeMtgyTokenAddy(address _tokenAddy) external onlyOwner {
    _mtgy = MTGY(_tokenAddy);
  }

  function changeSpendAddress(address _spendAddress) external onlyOwner {
    _spend = MTGYSpend(_spendAddress);
  }

  function changeMtgyServiceCost(uint256 _newCost) external onlyOwner {
    mtgyServiceCost = _newCost;
  }

  function _random(uint256 _entries) private view returns (uint256) {
    return
      uint256(
        keccak256(abi.encodePacked(block.difficulty, block.timestamp, _entries))
      );
  }
}
