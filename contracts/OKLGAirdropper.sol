// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC721.sol';
import './interfaces/IOKLGSpend.sol';
import './OKLGProduct.sol';

/**
 * @title OKLGAirdropper
 * @dev Allows sending ERC20 or ERC721 tokens to multiple addresses
 */
contract OKLGAirdropper is OKLGProduct {
  struct Receiver {
    address userAddress;
    uint256 amountOrTokenId;
  }

  constructor(address _tokenAddy, address _spendContractAddy)
    OKLGProduct(_tokenAddy, _spendContractAddy)
  {}

  function bulkSendMainTokens(
    bool _paymentInETH,
    Receiver[] memory _addressesAndAmounts
  ) external payable returns (bool) {
    _payForService(_paymentInETH);

    bool _wasSent = true;

    for (uint256 _i = 0; _i < _addressesAndAmounts.length; _i++) {
      Receiver memory _user = _addressesAndAmounts[_i];
      (bool sent, ) = _user.userAddress.call{ value: _user.amountOrTokenId }(
        ''
      );
      _wasSent = _wasSent == false ? false : sent;
    }
    return _wasSent;
  }

  function bulkSendErc20Tokens(
    bool _paymentInETH,
    address _tokenAddress,
    Receiver[] memory _addressesAndAmounts
  ) external returns (bool) {
    _payForService(_paymentInETH);

    IERC20 _token = IERC20(_tokenAddress);
    for (uint256 _i = 0; _i < _addressesAndAmounts.length; _i++) {
      Receiver memory _user = _addressesAndAmounts[_i];
      _token.transferFrom(msg.sender, _user.userAddress, _user.amountOrTokenId);
    }
    return true;
  }

  function bulkSendErc721Tokens(
    bool _paymentInETH,
    address _tokenAddress,
    Receiver[] memory _addressesAndAmounts
  ) external returns (bool) {
    _payForService(_paymentInETH);

    IERC721 _token = IERC721(_tokenAddress);
    for (uint256 _i = 0; _i < _addressesAndAmounts.length; _i++) {
      Receiver memory _user = _addressesAndAmounts[_i];
      _token.transferFrom(msg.sender, _user.userAddress, _user.amountOrTokenId);
    }
    return true;
  }
}
