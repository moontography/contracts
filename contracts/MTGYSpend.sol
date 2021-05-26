// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./MTGY.sol";

/**
 * @title MTGYSpend
 * @dev Logic for spending $MTGY on products in the moontography ecosystem.
 */
contract MTGYSpend {
    MTGY private _token;

    address public creator;
    address public constant burnWallet = 0x000000000000000000000000000000000000dEaD;
    address public devWallet = 0x3A3ffF4dcFCB7a36dADc40521e575380485FA5B8;
    address public rewardsWallet = 0x87644cB97C1e2Cc676f278C88D0c4d56aC17e838;
    address public mtgyTokenAddy = 0x025c9f1146d4d94F8F369B9d98104300A3c8ca23;

    event Spend(address indexed owner, uint256 value);

    constructor () public {
        creator = msg.sender;
        _token = MTGY(mtgyTokenAddy);
    }

    function changeMtgyTokenAddy(address tokenAddy) public {
      require(msg.sender == creator);
      mtgyTokenAddy = tokenAddy;
      _token = MTGY(tokenAddy);
    }

    function changeDevWallet(address newDevWallet) public {
      require(msg.sender == creator);
      devWallet = newDevWallet;
    }

    function changeRewardsWallet(address newRewardsWallet) public {
      require(msg.sender == creator);
      rewardsWallet = newRewardsWallet;
    }
    
    /**
    * spendOnProduct: used by a moontography product for a user to spend their tokens on usage of a product
    *   25% goes to dev wallet
    *   25% goes to rewards wallet for rewards
    *   50% burned
    */
    function spendOnProduct(uint256 productCostTokens) public returns (bool) {
      uint256 half = productCostTokens / uint(2);
      uint256 quarter = half / uint(2);
      
      // 50% burn
      _token.transferFrom(msg.sender, burnWallet, half);
      // 25% rewards wallet
      _token.transferFrom(msg.sender, rewardsWallet, quarter);
      // 25% dev wallet
      _token.transferFrom(msg.sender, devWallet, productCostTokens - half - quarter);
      emit Spend(msg.sender, productCostTokens);
      return true;
    }
}