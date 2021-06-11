// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import './MTGY.sol';
import './MTGYSpend.sol';

/**
 * @title MTGYPasswordManager
 * @dev Logic for storing and retrieving account information from the blockchain.
 */
contract MTGYPasswordManager {
  MTGY private _mtgy;
  MTGYSpend private _mtgySpend;

  address public creator;
  address public mtgyTokenAddy;
  address public mtgySpendAddy;
  uint256 public mtgyServiceCost = 500 * 10**18;

  struct AccountInfo {
    string id;
    uint256 timestamp;
    string accountData;
    bool isDeleted;
  }

  mapping(address => AccountInfo[]) public accountData;

  constructor(address _mtgyTokenAddy, address _mtgySpendAddy) {
    creator = msg.sender;
    mtgyTokenAddy = _mtgyTokenAddy;
    mtgySpendAddy = _mtgySpendAddy;
    _mtgy = MTGY(_mtgyTokenAddy);
    _mtgySpend = MTGYSpend(_mtgySpendAddy);
  }

  function changeMtgyTokenAddy(address _tokenAddy) public {
    require(
      msg.sender == creator,
      'changeMtgyTokenAddy user must be contract creator'
    );
    mtgyTokenAddy = _tokenAddy;
    _mtgy = MTGY(_tokenAddy);
  }

  function changeMtgySpendAddy(address _spendAddy) public {
    require(
      msg.sender == creator,
      'changeMtgyTokenAddy user must be contract creator'
    );
    mtgySpendAddy = _spendAddy;
    _mtgySpend = MTGYSpend(_spendAddy);
  }

  function changeServiceCost(uint256 _newCost) public {
    require(msg.sender == creator, 'user needs to be the contract creator');
    mtgyServiceCost = _newCost;
  }

  function getAllAccounts() public view returns (AccountInfo[] memory) {
    return accountData[msg.sender];
  }

  function getAccountById(string memory _id)
    public
    view
    returns (AccountInfo memory)
  {
    AccountInfo[] memory _userInfo = accountData[msg.sender];
    for (uint256 _i = 0; _i < _userInfo.length; _i++) {
      if (_compareStrings(_userInfo[_i].id, _id)) {
        return _userInfo[_i];
      }
    }
    return
      AccountInfo({ id: '', timestamp: 0, accountData: '', isDeleted: false });
  }

  function updateAccountById(string memory _id, string memory _newAccountData)
    public
  {
    AccountInfo[] memory _userInfo = accountData[msg.sender];
    for (uint256 _i = 0; _i < _userInfo.length; _i++) {
      if (_compareStrings(_userInfo[_i].id, _id)) {
        accountData[msg.sender][_i].accountData = _newAccountData;
      }
    }
  }

  function addAccount(string memory _id, string memory _accountData) public {
    _mtgy.transferFrom(msg.sender, address(this), mtgyServiceCost);
    _mtgy.approve(mtgySpendAddy, mtgyServiceCost);
    _mtgySpend.spendOnProduct(mtgyServiceCost);
    accountData[msg.sender].push(
      AccountInfo({
        id: _id,
        timestamp: block.timestamp,
        accountData: _accountData,
        isDeleted: false
      })
    );
  }

  function deleteAccount(string memory _id) public {
    AccountInfo[] memory _userInfo = accountData[msg.sender];
    for (uint256 _i = 0; _i < _userInfo.length; _i++) {
      if (_compareStrings(_userInfo[_i].id, _id)) {
        accountData[msg.sender][_i].isDeleted = true;
      }
    }
  }

  function _compareStrings(string memory a, string memory b)
    private
    pure
    returns (bool)
  {
    return (keccak256(abi.encodePacked((a))) ==
      keccak256(abi.encodePacked((b))));
  }
}
