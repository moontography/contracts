// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import './MTGYFaaSToken.sol';
import './MTGY.sol';
import './MTGYSpend.sol';

/**
 * @title MTGYFaaS (sMTGY)
 * @author Lance Whatley
 * @notice Implements the master FaaS contract to keep track of all tokens being added
 * to be staked and staking.
 */
contract MTGYFaaS {
  address public creator;
  MTGY public mtgyToken;
  MTGYSpend public mtgySpendContract;
  uint256 public mtgyServiceCost = 10000;

  // this is a mapping of tokenAddress => contractAddress[] that represents
  // a particular address for the token that someone has put up
  // to be staked and a list of contract addresses for the staking token
  // contracts paying out stakers for the given token.
  mapping(address => address[]) tokensUpForStaking;

  /**
   * @notice The constructor for the staking master contract.
   */
  constructor(address _mtgyAddress, address _mtgySpendAddress) {
    creator = msg.sender;
    mtgyToken = MTGY(_mtgyAddress);
    mtgySpendContract = MTGYSpend(_mtgySpendAddress);
  }

  function changeServiceCost(uint256 newCost) public {
    require(msg.sender == creator);
    mtgyServiceCost = newCost;
  }

  function createNewTokenContract(
    address _tokenAddy,
    uint256 _supply,
    uint256 _perBlockAllocation,
    uint256 _lockedUntilDate
  ) public {
    // pay the MTGY fee for using MTGYFaaS
    mtgyToken.transferFrom(msg.sender, address(this), mtgyServiceCost);
    mtgySpendContract.spendOnProduct(mtgyServiceCost);

    // create new MTGYFaaSToken contract which will serve as the core place for
    // users to stake their tokens and earn rewards
    ERC20 _sourceToken = ERC20(_tokenAddy);
    MTGYFaaSToken _contract =
      new MTGYFaaSToken(
        'Moontography Staking Token',
        'sMTGY',
        _supply,
        _tokenAddy,
        msg.sender,
        _perBlockAllocation,
        _lockedUntilDate
      );
    tokensUpForStaking[_tokenAddy].push(address(_contract));

    // Send the new contract all the tokens from the sending user to be staked and harvested
    _sourceToken.transfer(address(_contract), _supply);
  }

  function removeTokenContract(address _faasTokenAddy) public view {
    MTGYFaaSToken _contract = MTGYFaaSToken(_faasTokenAddy);
    require(msg.sender == _contract.originalTokenOwnerAddress());
    require(block.timestamp > _contract.lockedUntilDate());

    // TODO Loop through all stakers and harvest their tokens
    // using _contract.harvestTokensForUser(_userAddy)
  }
}
