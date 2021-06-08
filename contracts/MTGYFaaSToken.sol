// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import '../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol';
import '../node_modules/@openzeppelin/contracts/access/Ownable.sol';
import './MTGYFaaS.sol';

/**
 * @title MTGYFaaSToken (sMTGY)
 * @author Lance Whatley
 * @notice Represents a contract where a token owner has put her tokens up for others to stake and earn said tokens.
 */
contract MTGYFaaSToken is ERC20, Ownable {
  using SafeMath for uint256;

  address public creator;
  address public originalTokenOwnerAddress;
  uint256 public originalTotalSupply;
  address public tokenAddress;
  uint256 public totalTokensStaked;
  uint256 public contractCreationBlock;
  uint256 public perBlockTokenAmount;
  uint256 public lockedUntilDate;

  MTGYFaaS private parentFaasToken;
  ERC20 private token;
  address private constant burner = 0x000000000000000000000000000000000000dEaD;

  struct TokenHarvester {
    address tokenAddy;
    uint256 blockOriginallStaked;
    uint256 blockLastHarvested;
  }

  struct BlockTokenTotal {
    uint256 blockNumber;
    uint256 totalTokens;
  }

  // mapping of userAddresses => tokenAddresses that can
  // can be evaluated to determine for a particular user which tokens
  // they are staking.
  mapping(address => TokenHarvester) public tokenStakers;

  BlockTokenTotal[] public blockTotals;

  /**
   * @notice The constructor for the Staking Token.
   * @param _tokenAddy The token address for the staking contract
   * @param _supply The amount of tokens to mint on construction, this should be the same as the tokens provided by the creating user.
   */
  constructor(
    string memory _name,
    string memory _symbol,
    uint256 _supply,
    address _tokenAddy,
    address _originalTokenOwner,
    uint256 _perBlockAmount,
    uint256 _lockedUntilDate
  ) ERC20(_name, _symbol) {
    require(
      _perBlockAmount > uint256(0) && _perBlockAmount <= uint256(_supply),
      'per block amount must be more than 0 and less than supply'
    );

    // A locked date of '0' corresponds to being locked forever until the supply has expired and been rewards to all stakers
    require(
      _lockedUntilDate > block.timestamp || _lockedUntilDate == 0,
      'locked time must be after now or 0'
    );

    contractCreationBlock = block.number;
    creator = msg.sender;
    parentFaasToken = MTGYFaaS(creator);
    originalTotalSupply = _supply;
    originalTokenOwnerAddress = _originalTokenOwner;
    tokenAddress = _tokenAddy;
    perBlockTokenAmount = _perBlockAmount;
    lockedUntilDate = _lockedUntilDate;
    token = ERC20(_tokenAddy);
  }

  function updatePerBlockAmount(uint256 _amount) public {
    require(
      msg.sender == originalTokenOwnerAddress,
      'updatePerBlockAmount user must be original token owner'
    );
    perBlockTokenAmount = _amount;
  }

  function updateLockedTimestamp(uint256 _newTime) public {
    require(
      msg.sender == originalTokenOwnerAddress,
      'updateLockedTimestamp user must be original token owner'
    );
    require(
      _newTime > lockedUntilDate || _newTime == 0,
      'you cannot change timestamp if it is before the locked time or was set to be locked forever'
    );
    lockedUntilDate = _newTime;
  }

  function stakeTokens(uint256 _amount) public {
    require(
      token.balanceOf(msg.sender) >= _amount,
      'user must have enough tokens to stake said amount'
    );

    token.transferFrom(msg.sender, address(this), _amount);
    _mint(msg.sender, _amount);
    tokenStakers[msg.sender] = TokenHarvester({
      tokenAddy: address(token),
      blockOriginallStaked: block.number,
      blockLastHarvested: block.number
    });

    if (!parentFaasToken.doesUserHaveContract(msg.sender, address(this))) {
      parentFaasToken.addUserToContract(msg.sender, address(this));
    }
    _updateTotalTokenAmount(_amount, 'add');
  }

  function unstakeTokens(uint256 _amount) public {
    require(
      _amount <= balanceOf(msg.sender),
      'user can only unstake amount they have currently staked or less'
    );

    harvestTokens();
    transferFrom(msg.sender, burner, _amount);
    token.transfer(msg.sender, _amount);
    if (balanceOf(msg.sender) <= 0) {
      parentFaasToken.removeContractFromUser(msg.sender, address(this));
      delete tokenStakers[msg.sender];
    }

    _updateTotalTokenAmount(_amount, 'remove');
  }

  function harvestTokens() public returns (uint256) {
    return _harvestTokens(msg.sender);
  }

  function harvestTokensForUser(address _userAddy) public returns (uint256) {
    require(
      msg.sender == creator,
      'can only harvest tokens for someone else if this was the contract creator'
    );
    return _harvestTokens(_userAddy);
  }

  function getLastStakableBlock() public view returns (uint256) {
    return (originalTotalSupply / perBlockTokenAmount) + contractCreationBlock;
  }

  function calculateHarvestTokenTotalForUser(address _userAddy)
    public
    view
    returns (uint256)
  {
    TokenHarvester memory staker = tokenStakers[_userAddy];
    uint256 startBlockIndex = 0;
    for (uint256 _i; _i < blockTotals.length; _i++) {
      BlockTokenTotal memory curBlock = blockTotals[_i];
      if (curBlock.blockNumber > staker.blockLastHarvested) {
        startBlockIndex = _i - 1;
        break;
      }
    }

    uint256 latestBlock = block.number;
    uint256 lastPossibleBlock = getLastStakableBlock();
    if (lastPossibleBlock < latestBlock) {
      latestBlock = lastPossibleBlock;
    }

    uint256 tokensToHarvest = 0;
    BlockTokenTotal memory startTotal = blockTotals[startBlockIndex];
    for (
      uint256 _block = staker.blockLastHarvested;
      _block <= latestBlock;
      _block++
    ) {
      BlockTokenTotal memory nextTotal = blockTotals[startBlockIndex + 1];
      if (_block >= nextTotal.blockNumber) {
        startBlockIndex++;
        startTotal = blockTotals[startBlockIndex];
      }

      tokensToHarvest +=
        perBlockTokenAmount *
        (balanceOf(_userAddy) / startTotal.totalTokens);
    }
    return tokensToHarvest;
  }

  function _harvestTokens(address _userAddy) private returns (uint256) {
    TokenHarvester memory harvestAmount = tokenStakers[_userAddy];
    require(
      harvestAmount.blockOriginallStaked > 0,
      'user must have tokens staked'
    );

    uint256 blockDiff = block.number - harvestAmount.blockLastHarvested;
    require(blockDiff >= 0, 'must be after when the user last harvested');

    uint256 tokensToTransfer = calculateHarvestTokenTotalForUser(_userAddy);
    token.transfer(address(this), tokensToTransfer);
    tokenStakers[_userAddy].blockLastHarvested = block.number;
    return tokensToTransfer;
  }

  function _updateTotalTokenAmount(uint256 _amount, string memory _operation)
    private
  {
    if (_compareStrings(_operation, 'remove')) {
      totalTokensStaked = totalTokensStaked - _amount;
    } else {
      totalTokensStaked = totalTokensStaked + _amount;
    }

    BlockTokenTotal memory newBlockTotal =
      BlockTokenTotal({
        blockNumber: block.number,
        totalTokens: totalTokensStaked
      });
    blockTotals.push(newBlockTotal);
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
