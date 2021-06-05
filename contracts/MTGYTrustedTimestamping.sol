// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import './MTGY.sol';
import './MTGYSpend.sol';

/**
 * @title MTGYTrustedTimestamping
 * @dev Very simple example of a contract receiving ERC20 tokens.
 */
contract MTGYTrustedTimestamping {
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

  uint256 public cost = 1000 * 10**18;
  address public creator;
  address public spendAddress;
  mapping(address => DataHash[]) addressHashes;
  mapping(bytes32 => Address[]) fileHashesToAddress;

  event StoreHash(address from, bytes32 dataHash);

  constructor(address mtgyAddress, address mtgySpendAddress) {
    creator = msg.sender;
    spendAddress = mtgySpendAddress;
    _token = MTGY(mtgyAddress);
    _spend = MTGYSpend(spendAddress);

    _token.approve(spendAddress, cost);
  }

  /**
   * @dev If the price of MTGY changes significantly, need to be able to adjust price to keep cost appropriate for storing hashes
   */
  function changeCost(uint256 newCost) public {
    require(msg.sender == creator);
    _token.approve(spendAddress, cost);
    cost = newCost;
  }

  /**
   * @dev Process transaction and store hash in blockchain
   */
  function storeHash(
    bytes32 dataHash,
    string memory fileName,
    uint256 fileSizeBytes
  ) public {
    address from = msg.sender;

    _token.transferFrom(from, address(this), cost);
    _spend.spendOnProduct(cost);
    uint256 theTimeNow = block.timestamp;
    addressHashes[from].push(
      DataHash({
        dataHash: dataHash,
        time: theTimeNow,
        fileName: fileName,
        fileSizeBytes: fileSizeBytes
      })
    );
    fileHashesToAddress[dataHash].push(
      Address({ addy: from, time: theTimeNow })
    );
    emit StoreHash(from, dataHash);
  }

  function getHashesFromAddress(address addy)
    public
    view
    returns (DataHash[] memory)
  {
    return addressHashes[addy];
  }

  function getAddressesFromHash(bytes32 dataHash)
    public
    view
    returns (Address[] memory)
  {
    return fileHashesToAddress[dataHash];
  }
}
