// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import './MTGYFaaSToken.sol';
import './MTGYSpend.sol';

/**
 * @title MTGYFaaS (sMTGY)
 * @author Lance Whatley
 * @notice Implements the master FaaS contract to keep track of all tokens being added
 * to be staked and staking.
 */
contract MTGYFaaS {
  ERC20 private _mtgy;
  MTGYSpend private _spend;

  address public creator;
  uint256 public mtgyServiceCost = 100000 * 10**18;

  // this is a mapping of tokenAddress => contractAddress[] that represents
  // a particular address for the token that someone has put up
  // to be staked and a list of contract addresses for the staking token
  // contracts paying out stakers for the given token.
  mapping(address => address[]) public tokensUpForStaking;
  address[] public allFarmingContracts;
  uint256 public totalStakingContracts;

  // mapping of userAddress => contractAddress[] that provides all the
  // user's sMTGY contracts they're staking tokens with
  mapping(address => address[]) public userStakes;
  address[] public allUsersStaking;

  /**
   * @notice The constructor for the staking master contract.
   */
  constructor(address _mtgyAddress, address _mtgySpendAddress) {
    creator = msg.sender;
    _mtgy = ERC20(_mtgyAddress);
    _spend = MTGYSpend(_mtgySpendAddress);
  }

  function getAllFarmingContracts() public view returns (address[] memory) {
    return allFarmingContracts;
  }

  function getTokensForStaking(address _tokenAddress)
    public
    view
    returns (address[] memory)
  {
    return tokensUpForStaking[_tokenAddress];
  }

  function getUserStakingContracts(address _userAddress)
    public
    view
    returns (address[] memory)
  {
    return userStakes[_userAddress];
  }

  function changeServiceCost(uint256 newCost) public {
    require(msg.sender == creator, 'user needs to be the contract creator');
    mtgyServiceCost = newCost;
  }

  function createNewTokenContract(
    address _rewardsTokenAddy,
    address _stakedTokenAddy,
    uint256 _supply,
    uint256 _perBlockAllocation,
    uint256 _lockedUntilDate
  ) public {
    // pay the MTGY fee for using MTGYFaaS
    _mtgy.transferFrom(msg.sender, address(this), mtgyServiceCost);
    _mtgy.approve(address(_spend), mtgyServiceCost);
    _spend.spendOnProduct(mtgyServiceCost);

    // create new MTGYFaaSToken contract which will serve as the core place for
    // users to stake their tokens and earn rewards
    ERC20 _rewToken = ERC20(_rewardsTokenAddy);
    MTGYFaaSToken _contract =
      new MTGYFaaSToken(
        'Moontography Staking Token',
        'sMTGY',
        _supply,
        _rewardsTokenAddy,
        _stakedTokenAddy,
        msg.sender,
        _perBlockAllocation,
        _lockedUntilDate
      );
    allFarmingContracts.push(address(_contract));
    tokensUpForStaking[_stakedTokenAddy].push(address(_contract));
    totalStakingContracts++;

    // Send the new contract all the tokens from the sending user to be staked and harvested
    _rewToken.transferFrom(msg.sender, address(this), _supply);
    _rewToken.transfer(address(_contract), _supply);
  }

  // function removeTokenContract(address _faasTokenAddy) public {
  //   MTGYFaaSToken _contract = MTGYFaaSToken(_faasTokenAddy);
  //   require(
  //     msg.sender == _contract.tokenOwner(),
  //     'user must be the original token owner to remove tokens'
  //   );
  //   require(
  //     block.timestamp > _contract.lockedUntilDate() &&
  //       _contract.lockedUntilDate() != 0,
  //     'it must be after the locked time the user originally configured and not locked forever'
  //   );

  //   for (uint256 _i = 0; _i < allUsersStaking.length; _i++) {
  //     _contract.harvestForUser(allUsersStaking[_i]);
  //   }
  //   _contract.removeStakeableTokens();
  //   totalStakingContracts--;
  // }

  function userInd(address _addy) public view returns (int256) {
    for (uint256 _i = 0; _i < allUsersStaking.length; _i++) {
      if (allUsersStaking[_i] == _addy) {
        return int256(_i);
      }
    }
    return -1;
  }

  function addUserAsStaking(address _addy) public {
    int256 ind = userInd(_addy);
    if (ind == -1) {
      allUsersStaking.push(_addy);
    }
  }

  function removeUserAsStaking(address _addy) public {
    int256 ind = userInd(_addy);
    if (ind > -1) {
      uint256 sind = uint256(ind);
      delete allUsersStaking[sind];
    }
  }

  function doesUserHaveContract(address _userAddress, address _stakingContract)
    public
    view
    returns (bool)
  {
    for (uint256 _i = 0; _i < userStakes[_userAddress].length; _i++) {
      if (userStakes[_userAddress][_i] == _stakingContract) {
        return true;
      }
    }
    return false;
  }

  function addUserToContract(address _userAddress, address _stakingContract)
    public
  {
    require(
      msg.sender == _stakingContract,
      'addUserToContract calling address must be staking contract'
    );
    MTGYFaaSToken _contract = MTGYFaaSToken(_stakingContract);
    require(_contract.balanceOf(_userAddress) > 0);
    userStakes[_userAddress].push(_stakingContract);
  }

  function removeContractFromUser(address _userAddress, address _stakingAddy)
    public
  {
    require(
      msg.sender == _stakingAddy,
      'removeContractFromUser calling address must be staking contract'
    );
    MTGYFaaSToken _contract = MTGYFaaSToken(_stakingAddy);
    require(_contract.balanceOf(_userAddress) == 0);
    for (uint256 _i = 0; _i < userStakes[_userAddress].length; _i++) {
      if (userStakes[_userAddress][_i] == _stakingAddy) {
        delete userStakes[_userAddress][_i];
      }
    }
  }
}
