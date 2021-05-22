// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import "./MTGY.sol";

/**
 * @title TrustedTimestamping
 * @dev Very simple example of a contract receiving ERC20 tokens.
 */
contract TrustedTimestamping {
    MTGY private _token;
    uint public cost = 1000 * 10**18;
    address public creator;
    mapping(address => bytes32[]) addressHashes;
    mapping(bytes32 => address[]) fileHashesToAddress;

    event StoreHash(address from, bytes32 dataHash);

    constructor (address mtgyAddress) public {
        creator = msg.sender;
        _token = MTGY(mtgyAddress);
    }
    
    /**
     * @dev If the price of MTGY changes significantly, need to be able to adjust price to keep cost appropriate for storing hashes
     */
    function changeCost(uint newCost) public {
        require(msg.sender == creator);
        cost = newCost;
    }

    /**
     * @dev Process transaction and store hash in blockchain
     */
    function storeHash(bytes32 dataHash) public payable {
        address from = msg.sender;
        _token.spendOnProduct(cost);
        addressHashes[msg.sender].push(dataHash);
        fileHashesToAddress[dataHash].push(msg.sender);
        emit StoreHash(from, dataHash);
    }
}