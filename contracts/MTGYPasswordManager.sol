// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import './MTGY.sol';
import './MTGYSpend.sol';

/**
 * @title MTGYPasswordManager
 * @dev Logic for storing and retrieving account information from the blockchain.
 */
contract MTGYPasswordManager {
  using SafeMath for uint256;

  MTGY private _mtgy;
  MTGYSpend private _mtgySpend;

  address public creator;
  address public mtgyTokenAddy;
  address public mtgySpendAddy;
  uint256 public mtgyServiceCost = 100 * 10**18;

  struct AccountInfo {
    string id;
    uint256 timestamp;
    string iv;
    string ciphertext;
    bool isDeleted;
  }

  // the normal mapping of all accounts owned by a user
  mapping(address => AccountInfo[]) public userAccounts;

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

  function getAllAccounts(address _userAddy)
    public
    view
    returns (AccountInfo[] memory)
  {
    return userAccounts[_userAddy];
  }

  function getAccountById(string memory _id)
    public
    view
    returns (AccountInfo memory)
  {
    AccountInfo[] memory _userInfo = userAccounts[msg.sender];
    for (uint256 _i = 0; _i < _userInfo.length; _i++) {
      if (_compareStr(_userInfo[_i].id, _id)) {
        return _userInfo[_i];
      }
    }
    return
      AccountInfo({
        id: '',
        timestamp: 0,
        iv: '',
        ciphertext: '',
        isDeleted: false
      });
  }

  function updateAccountById(
    string memory _id,
    string memory _newIv,
    string memory _newAccountData
  ) public returns (bool) {
    AccountInfo[] memory _userInfo = userAccounts[msg.sender];
    for (uint256 _i = 0; _i < _userInfo.length; _i++) {
      if (_compareStr(_userInfo[_i].id, _id)) {
        userAccounts[msg.sender][_i].iv = _newIv;
        userAccounts[msg.sender][_i].timestamp = block.timestamp;
        userAccounts[msg.sender][_i].ciphertext = _newAccountData;
        return true;
      }
    }
    return false;
  }

  function addAccount(
    string memory _id,
    string memory _iv,
    string memory _ciphertext
  ) public {
    _mtgy.transferFrom(msg.sender, address(this), mtgyServiceCost);
    _mtgy.approve(mtgySpendAddy, mtgyServiceCost);
    _mtgySpend.spendOnProduct(mtgyServiceCost);
    userAccounts[msg.sender].push(
      AccountInfo({
        id: _id,
        timestamp: block.timestamp,
        iv: _iv,
        ciphertext: _ciphertext,
        isDeleted: false
      })
    );
  }

  function bulkAddAccounts(AccountInfo[] memory accounts) public {
    require(
      accounts.length >= 5,
      'you need a minimum of 5 accounts too add in bulk at a 50% discount service cost'
    );
    uint256 _serviceCostAdjusted = mtgyServiceCost.mul(accounts.length).div(2);
    _mtgy.transferFrom(msg.sender, address(this), _serviceCostAdjusted);
    _mtgy.approve(mtgySpendAddy, _serviceCostAdjusted);
    _mtgySpend.spendOnProduct(_serviceCostAdjusted);
    for (uint256 _i = 0; _i < accounts.length; _i++) {
      AccountInfo memory _account = accounts[_i];
      userAccounts[msg.sender].push(
        AccountInfo({
          id: _account.id,
          timestamp: block.timestamp,
          iv: _account.iv,
          ciphertext: _account.ciphertext,
          isDeleted: false
        })
      );
    }
  }

  function deleteAccount(string memory _id) public returns (bool) {
    AccountInfo[] memory _userInfo = userAccounts[msg.sender];
    for (uint256 _i = 0; _i < _userInfo.length; _i++) {
      if (_compareStr(_userInfo[_i].id, _id)) {
        userAccounts[msg.sender][_i].timestamp = block.timestamp;
        userAccounts[msg.sender][_i].isDeleted = true;
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
