// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import '../node_modules/@openzeppelin/contracts/access/Ownable.sol';
import './MTGY.sol';
import './MTGYSpend.sol';
import './MTGYAtomicSwapInstance.sol';

/**
 * @title MTGYAtomicSwap
 * @dev This is the main contract that supports holding metadata for MTGY atomic inter and intrachain swapping
 */
contract MTGYAtomicSwap is Ownable {
  struct TargetSwapInfo {
    address sourceContract;
    string targetNetwork;
    address targetContract;
    bool isActive;
  }

  MTGY private _mtgy;
  MTGYSpend private _spend;

  uint256 public mtgyServiceCost = 25000 * 10**18;
  uint256 public swapCreationGasLoadAmount = 2 * 10**16; // 0.02 ether
  address public creator;
  address payable public oracleAddress;

  // mapping with "0xSourceNetworkContract" => targetNetworkContractInfo that
  // our oracle can query and get the target network contract as needed.
  TargetSwapInfo[] public targetSwapContracts;
  mapping(address => TargetSwapInfo) public targetSwapContractsIndexed;

  // ASContract => contractCreators so we can store who created the source network
  // AS contract for permissioning of changing any data
  mapping(address => address) public contractCreators;

  event CreateSwapContract(
    uint256 swapContractIndex,
    address contractAddress,
    string targetNetwork,
    address indexed targetContract,
    address creator
  );

  constructor(
    address _mtgyAddress,
    address _mtgySpendAddress,
    address _oracleAddress
  ) {
    creator = msg.sender;
    _mtgy = MTGY(_mtgyAddress);
    _spend = MTGYSpend(_mtgySpendAddress);
    oracleAddress = payable(_oracleAddress);
  }

  function updateSwapCreationGasLoadAmount(uint256 _amount) public onlyOwner() {
    swapCreationGasLoadAmount = _amount;
  }

  function changeOracleAddress(address _oracleAddress, bool _changeAll)
    public
    onlyOwner()
  {
    oracleAddress = payable(_oracleAddress);
    if (_changeAll) {
      for (uint256 _i = 0; _i < targetSwapContracts.length; _i++) {
        MTGYAtomicSwapInstance _contract =
          MTGYAtomicSwapInstance(targetSwapContracts[_i].sourceContract);
        _contract.changeOracleAddress(oracleAddress);
      }
    }
  }

  function changeMtgyTokenAddy(address _tokenAddy) public onlyOwner() {
    _mtgy = MTGY(_tokenAddy);
  }

  function changeSpendAddress(address _spendAddress) public onlyOwner() {
    _spend = MTGYSpend(_spendAddress);
  }

  /**
   * @dev If the price of MTGY changes significantly, need to be able to adjust price
   * to keep cost appropriate for providing the service
   */
  function changeMtgyServiceCost(uint256 _newCost) public onlyOwner() {
    mtgyServiceCost = _newCost;
  }

  function getAllSwapContracts() public view returns (TargetSwapInfo[] memory) {
    return targetSwapContracts;
  }

  function updateSwapContract(
    uint256 _index,
    address _sourceContract,
    string memory _targetNetwork,
    address _targetContract,
    bool _isActive
  ) public {
    require(
      msg.sender == creator ||
        msg.sender == contractCreators[_sourceContract] ||
        msg.sender == oracleAddress,
      'updateSwapContract must be contract creator'
    );
    targetSwapContracts[_index] = TargetSwapInfo({
      sourceContract: _sourceContract,
      targetNetwork: _targetNetwork,
      targetContract: _targetContract,
      isActive: _isActive
    });
    targetSwapContractsIndexed[_sourceContract] = targetSwapContracts[_index];
  }

  function createNewAtomicSwapContract(
    address _tokenAddy,
    uint256 _tokenSupply,
    uint256 _maxSwapAmount,
    string memory _targetNetwork,
    address _targetContract
  ) public payable {
    require(
      msg.value >= swapCreationGasLoadAmount,
      'Going to ask the user to fill up the atomic swap contract with some gas'
    );
    _mtgy.transferFrom(msg.sender, address(this), mtgyServiceCost);
    _mtgy.approve(address(_spend), mtgyServiceCost);
    _spend.spendOnProduct(mtgyServiceCost);

    MTGYAtomicSwapInstance _contract =
      new MTGYAtomicSwapInstance(
        oracleAddress,
        msg.sender,
        _tokenAddy,
        _maxSwapAmount
      );
    oracleAddress.transfer(msg.value);
    ERC20 _token = ERC20(_tokenAddy);
    _token.transferFrom(msg.sender, address(_contract), _tokenSupply);
    _contract.updateSupply();

    targetSwapContracts.push(
      TargetSwapInfo({
        sourceContract: address(_contract),
        targetNetwork: _targetNetwork,
        targetContract: _targetContract,
        isActive: true
      })
    );
    targetSwapContractsIndexed[address(_contract)] = targetSwapContracts[
      targetSwapContracts.length - 1
    ];
    contractCreators[address(_contract)] = msg.sender;
    emit CreateSwapContract(
      targetSwapContracts.length - 1,
      address(_contract),
      _targetNetwork,
      _targetContract,
      msg.sender
    );
  }
}
