// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import '../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol';
import '../node_modules/@openzeppelin/contracts/access/Ownable.sol';

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
  uint256 public perBlockTokenAmount;
  uint256 public lockedUntilDate;

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
  mapping(address => TokenHarvester) tokenStakers;

  BlockTokenTotal[] blockTotals;

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
    require(_perBlockAmount > uint256(0));

    // A locked date of '0' corresponds to being locked forever until the supply has expired and been rewards to all stakers
    require(_lockedUntilDate > block.timestamp || _lockedUntilDate == 0);

    creator = msg.sender;
    originalTotalSupply = _supply;
    originalTokenOwnerAddress = _originalTokenOwner;
    tokenAddress = _tokenAddy;
    perBlockTokenAmount = _perBlockAmount;
    lockedUntilDate = _lockedUntilDate;
    token = ERC20(_tokenAddy);
    token.transferFrom(originalTokenOwnerAddress, creator, _supply);
    // when we create this new contract, after this instance is created the parent
    // main FaaS contract sends all it's tokens to this address to be used for
    // harvesting and distribution so no need to do anything else here
  }

  function updatePerBlockAmount(uint256 _amount) public {
    require(msg.sender == originalTokenOwnerAddress);
    perBlockTokenAmount = _amount;
  }

  function updateLockedTimestamp(uint256 _newTime) public {
    require(msg.sender == originalTokenOwnerAddress);
    require(_newTime > lockedUntilDate || _newTime == 0);
    lockedUntilDate = _newTime;
  }

  function stakeTokens(uint256 _amount) public {
    require(token.balanceOf(msg.sender) >= _amount);

    _mint(address(this), _amount);
    token.transferFrom(msg.sender, address(this), _amount);
    transfer(msg.sender, _amount);
    tokenStakers[msg.sender] = TokenHarvester({
      tokenAddy: address(token),
      blockOriginallStaked: block.number,
      blockLastHarvested: block.number
    });

    _updateTotalTokenAmount(_amount, 'add');
  }

  function unstakeTokens(uint256 _amount) public {
    require(_amount <= balanceOf(msg.sender));

    harvestTokens();
    transferFrom(msg.sender, burner, _amount);
    token.transfer(msg.sender, _amount);
    if (balanceOf(msg.sender) <= 0) {
      delete tokenStakers[msg.sender];
    }

    _updateTotalTokenAmount(_amount, 'remove');
  }

  function harvestTokens() public returns (uint256) {
    return _harvestTokens(msg.sender);
  }

  function harvestTokensForUser(address _userAddy) public returns (uint256) {
    require(msg.sender == creator);
    return _harvestTokens(_userAddy);
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

    uint256 tokensToHarvest = 0;
    BlockTokenTotal memory startTotal = blockTotals[startBlockIndex];
    for (
      uint256 _block = staker.blockLastHarvested;
      _block <= block.number;
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
    require(harvestAmount.blockOriginallStaked > 0);

    uint256 blockDiff = block.number - harvestAmount.blockLastHarvested;
    require(blockDiff >= 0);

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
