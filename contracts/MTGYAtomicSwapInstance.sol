// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import '../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '../node_modules/@openzeppelin/contracts/access/Ownable.sol';

/**
 * @title MTGYAtomicSwapInstance
 * @dev This is the main contract that supports holding metadata for MTGY atomic inter and intrachain swapping
 */
contract MTGYAtomicSwapInstance is Ownable {
  ERC20 private _token;

  address public creator;
  address public tokenOwner;
  address public oracleAddress;
  uint256 public originalSupply;
  uint256 public maxSwapAmount;
  uint256 public minimumGasOnReceive = 4 * 10**15; // 4 finney (0.004 ETH)
  bool public isActive = true;

  struct Swap {
    uint256 origTimestamp;
    uint256 currentTimestamp;
    bool isOutbound;
    bool isComplete;
    address swapAddress;
    uint256 amount;
  }

  mapping(bytes32 => Swap) public swaps;

  event ReceiveTokensFromSource(
    bytes32 indexed id,
    uint256 origTimestamp,
    address sender,
    uint256 amount
  );

  event SendTokensToDestination(
    bytes32 indexed id,
    address receiver,
    uint256 amount
  );

  constructor(
    address _oracleAddress,
    address _tokenOwner,
    address _tokenAddy,
    uint256 _maxSwapAmount
  ) {
    creator = msg.sender;
    oracleAddress = _oracleAddress;
    tokenOwner = _tokenOwner;
    maxSwapAmount = _maxSwapAmount;
    transferOwnership(oracleAddress);
    _token = ERC20(_tokenAddy);
  }

  function changeActiveState(bool _isActive) public {
    require(
      msg.sender == creator || msg.sender == tokenOwner,
      'changeActiveState user must be contract creator'
    );
    isActive = _isActive;
  }

  // should only be called after we instantiate a new instance of
  // this and it's to handle weird tokenomics where we don't get
  // original full supply
  function updateSupply() public {
    require(
      msg.sender == creator,
      'updateSupply user must be contract creator'
    );
    originalSupply = _token.balanceOf(address(this));
  }

  function changeOracleAddress(address _oracleAddress) public {
    require(
      msg.sender == creator || msg.sender == owner(),
      'updateSupply user must be contract creator'
    );
    oracleAddress = _oracleAddress;
    transferOwnership(oracleAddress);
  }

  function depositTokens(uint256 _amount) public {
    require(msg.sender == tokenOwner, 'depositTokens user must be token owner');
    _token.transferFrom(msg.sender, address(this), _amount);
  }

  function withdrawTokens(uint256 _amount) public {
    require(
      msg.sender == tokenOwner,
      'withdrawTokens user must be token owner'
    );
    _token.transfer(msg.sender, _amount);
  }

  function updateSwapCompletionStatus(bytes32 _id, bool _isComplete)
    public
    onlyOwner()
  {
    swaps[_id].isComplete = _isComplete;
  }

  function updateMinimumGasOnReceive(uint256 _amountGas) public onlyOwner() {
    minimumGasOnReceive = _amountGas;
  }

  function receiveTokensFromSource(uint256 _amount)
    public
    payable
    returns (bytes32)
  {
    require(isActive, 'this atomic swap instance is not active');
    require(
      msg.value >= minimumGasOnReceive,
      'you must also send enough gas to cover the target transaction'
    );

    payable(oracleAddress).transfer(msg.value);
    _token.transferFrom(msg.sender, address(this), _amount);

    uint256 _ts = block.timestamp;
    bytes32 _id = sha256(abi.encodePacked(msg.sender, _ts));
    swaps[_id] = Swap({
      origTimestamp: _ts,
      currentTimestamp: _ts,
      isOutbound: false,
      isComplete: false,
      swapAddress: msg.sender,
      amount: _amount
    });
    emit ReceiveTokensFromSource(_id, _ts, msg.sender, _amount);
    return _id;
  }

  function sendTokensToDestination(
    bytes32 _id,
    uint256 _origTimestamp,
    address _destination,
    uint256 _amount
  ) public returns (bytes32) {
    require(isActive, 'this atomic swap instance is not active');
    require(
      msg.sender == oracleAddress || msg.sender == tokenOwner,
      'sendTokens user must be oracle or token owner'
    );
    require(
      maxSwapAmount == 0 || _amount <= maxSwapAmount,
      'trying to send more than maxSwapAmount'
    );

    // we generated a SHA256 hash with the original user who sent her tokens
    // and the original block timestamp. We're just validating here that they
    // match and that the swap has not been completed before moving forward.
    require(
      _id == sha256(abi.encodePacked(_destination, _origTimestamp)) &&
        !swaps[_id].isComplete,
      'swap has already been completed or we do not recognize this swap'
    );
    _token.transfer(_destination, _amount);
    swaps[_id] = Swap({
      origTimestamp: _origTimestamp,
      currentTimestamp: block.timestamp,
      isOutbound: true,
      isComplete: true,
      swapAddress: _destination,
      amount: _amount
    });
    emit SendTokensToDestination(_id, _destination, _amount);
    return _id;
  }
}
