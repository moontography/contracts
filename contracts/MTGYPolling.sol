// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';
import './MTGY.sol';
import './MTGYSpend.sol';

/**
 * @title MTGYPolling
 * @dev Logic for storing and retrieving poll information from the blockchain.
 */
contract MTGYPolling is Ownable {
  using SafeMath for uint256;

  MTGY private _mtgy;
  MTGYSpend private _mtgySpend;

  address public mtgyTokenAddy;
  address public mtgySpendAddy;
  uint256 public mtgyServiceCost = 100 * 10**18;

  struct PollInfo {
    string id;
    string text; // poll text
    uint256 createdAt; // unix timestamp of when this poll was created
    uint256 closesAt; // unix timestamp of when this poll will close
    bool isDeleted;
  }

  struct PollOptionInfo {
    string id;
    string pollId; // id of poll this option is tied to
    string text; // poll option text
    bool isDeleted;
  }

  // mapping of all polls owned by a user
  mapping(address => PollInfo[]) public userPolls;

  constructor(address _mtgyTokenAddy, address _mtgySpendAddy) {
    mtgyTokenAddy = _mtgyTokenAddy;
    mtgySpendAddy = _mtgySpendAddy;
    _mtgy = MTGY(_mtgyTokenAddy);
    _mtgySpend = MTGYSpend(_mtgySpendAddy);
  }

  function changeMtgyTokenAddy(address _tokenAddy) external onlyOwner {
    mtgyTokenAddy = _tokenAddy;
    _mtgy = MTGY(_tokenAddy);
  }

  function changeMtgySpendAddy(address _spendAddy) external onlyOwner {
    mtgySpendAddy = _spendAddy;
    _mtgySpend = MTGYSpend(_spendAddy);
  }

  function changeServiceCost(uint256 _newCost) external onlyOwner {
    mtgyServiceCost = _newCost;
  }
  
  function getAllPolls(address _userAddy)
    external
    view
    returns (PollInfo[] memory)
  {
    return PollInfo[_userAddy];
  }

  function getPollById(string memory _id)
    external
    view
    returns (PollInfo memory)
  {
    PollInfo[] memory _userInfo = userPolls[msg.sender];
    for (uint256 _i = 0; _i < _userInfo.length; _i++) {
      if (_compareStr(_userInfo[_i].id, _id)) {
        return _userInfo[_i];
      }
    }
    return
      PollInfo({
        id: '',
        text: '',
        createdAt: 0,
        closesAt: 0,
        isDeleted: false
      });
  }

  function createPoll(
    string memory _id,
    string memory _text,
    uint256 memory _closesAt
  ) external {
    _mtgy.transferFrom(msg.sender, address(this), mtgyServiceCost);
    _mtgy.approve(mtgySpendAddy, mtgyServiceCost);
    _mtgySpend.spendOnProduct(mtgyServiceCost);

    userPolls[msg.sender].push(
      PollInfo({
        id: _id,
        text: _text,
        createdAt: block.timestamp,
        closesAt: _closesAt,
        isDeleted: false
      })
    );
  }

  function deletePoll(string memory _id) external returns (bool) {
    PollInfo[] memory _userInfo = userPolls[msg.sender];
    for (uint256 _i = 0; _i < _userInfo.length; _i++) {
      if (_compareStr(_userInfo[_i].id, _id)) {
        userPolls[msg.sender][_i].isDeleted = true;
        return true;
      }
    }
    return false;
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
