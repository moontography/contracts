// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';
import './MTGY.sol';
import './MTGYSpend.sol';

/**
 * @title MTGYTrustedTimestamping
 * @dev Very simple example of a contract receiving ERC20 tokens.
 */
contract MTGYTrustedTimestamping is Ownable {
  MTGY private _token;
  MTGYSpend private _spend;

  struct DataHash {
    bytes32 dataHash;
    uint256 time;
    string fileName;
    uint256 fileSizeBytes;
  }

  struct Address {
    address addy;
    uint256 time;
  }

  uint256 public mtgyServiceCost = 100 * 10**18;
  address public spendAddress;
  uint256 public totalNumberHashesStored;
  mapping(address => DataHash[]) public addressHashes;
  mapping(bytes32 => Address[]) public fileHashesToAddress;

  event StoreHash(address from, bytes32 dataHash);

  constructor(address _mtgyAddress, address _mtgySpendAddress) {
    spendAddress = _mtgySpendAddress;
    _token = MTGY(_mtgyAddress);
    _spend = MTGYSpend(spendAddress);
  }

  function changeSpendAddress(address _spendAddress) external onlyOwner {
    spendAddress = _spendAddress;
    _spend = MTGYSpend(spendAddress);
  }

  /**
   * @dev If the price of MTGY changes significantly, need to be able to adjust price to keep cost appropriate for storing hashes
   */
  function changeMtgyServiceCost(uint256 _newCost) external onlyOwner {
    mtgyServiceCost = _newCost;
  }

  /**
   * @dev Process transaction and store hash in blockchain
   */
  function storeHash(
    bytes32 dataHash,
    string memory fileName,
    uint256 fileSizeBytes
  ) external {
    _token.transferFrom(msg.sender, address(this), mtgyServiceCost);
    _token.approve(spendAddress, mtgyServiceCost);
    _spend.spendOnProduct(mtgyServiceCost);
    uint256 theTimeNow = block.timestamp;
    addressHashes[msg.sender].push(
      DataHash({
        dataHash: dataHash,
        time: theTimeNow,
        fileName: fileName,
        fileSizeBytes: fileSizeBytes
      })
    );
    fileHashesToAddress[dataHash].push(
      Address({ addy: msg.sender, time: theTimeNow })
    );
    totalNumberHashesStored++;
    emit StoreHash(msg.sender, dataHash);
  }

  function getHashesForAddress(address _userAddy)
    external
    view
    returns (DataHash[] memory)
  {
    return addressHashes[_userAddy];
  }

  function getAddressesForHash(bytes32 dataHash)
    external
    view
    returns (Address[] memory)
  {
    return fileHashesToAddress[dataHash];
  }
}
