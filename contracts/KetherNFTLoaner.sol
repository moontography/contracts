// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import 'ketherhomepage/contracts/KetherNFT.sol';

/**
 * @title KetherNFTLoaner
 * @dev Support loaning KetherNFT plots of ad space to others over a period of time
 */
contract KetherNFTLoaner is Ownable {
  using SafeMath for uint256;

  uint256 private constant _1ETH = 1 ether;
  uint256 public loanServiceCharge = _1ETH.div(100);
  uint256 public minLoanChargePerDay = _1ETH.div(1000);
  uint256 public maxLoanDurationDays = 30;
  uint256 public loanPercentageCharge = 10;
  KetherNFT private _ketherNft;

  struct PlotOwner {
    address owner;
    uint256 overrideMinLoanChargePerDay;
    uint256 overrideMaxLoanDurationDays;
  }

  struct PlotLoan {
    address loaner;
    uint256 start;
    uint256 end;
  }

  struct PublishParams {
    string link;
    string image;
    string title;
    bool NSFW;
  }

  PlotOwner[] public owners;
  PlotLoan[] public loans;

  constructor(address _ketherNFTAddress) {
    _ketherNft = KetherNFT(_ketherNFTAddress);
  }

  function addPlot(uint256 _idx) external payable {
    require(
      msg.sender == _ketherNft.ownerOf(_idx),
      'You need to be the owner of the plot to loan it out.'
    );
    require(
      msg.value >= loanServiceCharge,
      'You must send the appropriate service charge to support loaning your plot.'
    );
    payable(owner()).call{ value: msg.value }('');
    _ketherNft.safeTransferFrom(msg.sender, address(this), _idx);
    owners[_idx].owner = msg.sender;
  }

  function removePlot(uint256 _idx) external {
    address _owner = owners[_idx].owner;
    require(
      msg.sender == _owner,
      'You must be the original owner of the plot to remove it from the loan contract.'
    );
    require(
      !hasActiveLoan(_idx),
      'There is currently an active loan on your plot that must expire before you can remove.'
    );
    _ketherNft.safeTransferFrom(address(this), msg.sender, _idx);
  }

  function loanPlot(
    uint256 _idx,
    uint256 _numDays,
    PublishParams memory _publishParams
  ) external payable {
    PlotOwner memory _owner = owners[_idx];
    PlotLoan memory _loan = loans[_idx];
    require(_loan.end < block.timestamp, 'Plot is currently being loaned.');

    _ensureValidLoanDays(_owner, _numDays);
    _ensureValidLoanCharge(_owner, _numDays);

    uint256 _serviceCharge = msg.value.mul(loanPercentageCharge).div(100);
    uint256 _ownerCharge = msg.value.sub(_serviceCharge);

    payable(owner()).call{ value: _serviceCharge }('');
    payable(_owner.owner).call{ value: _ownerCharge }('');

    loans[_idx] = PlotLoan({
      loaner: msg.sender,
      start: block.timestamp,
      end: block.timestamp.add(_daysToSeconds(_numDays))
    });
    publish(_idx, _publishParams);
  }

  function publish(uint256 _idx, PublishParams memory _publishParams) public {
    PlotOwner memory _owner = owners[_idx];
    PlotLoan memory _loan = loans[_idx];

    bool _hasActiveLoan = hasActiveLoan(_idx);
    if (_hasActiveLoan) {
      require(
        msg.sender == _loan.loaner,
        'Must be the current loaner to update published information.'
      );
    } else {
      require(
        msg.sender == _owner.owner,
        'Must be the owner to update published information.'
      );
    }

    _ketherNft.publish(
      _idx,
      _publishParams.link,
      _publishParams.image,
      _publishParams.title,
      _publishParams.NSFW
    );
  }

  function hasActiveLoan(uint256 _idx) public view returns (bool) {
    PlotLoan memory _loan = loans[_idx];
    require(
      _loan.loaner != address(0),
      'This plot has not been loaned out yet.'
    );
    return _loan.end > block.timestamp;
  }

  function setLoanServiceCharge(uint256 _amountEth) external onlyOwner {
    loanServiceCharge = _amountEth;
  }

  function setMinimumLoanAmountPerDay(uint256 _amountEth) external onlyOwner {
    minLoanChargePerDay = _amountEth;
  }

  function setMaxLoanDurationDays(uint256 _numDays) external onlyOwner {
    maxLoanDurationDays = _numDays;
  }

  function setLoanPercentageCharge(uint256 _percentage) external onlyOwner {
    loanPercentageCharge = _percentage;
  }

  function _daysToSeconds(uint256 _days) private pure returns (uint256) {
    return _days.mul(24).mul(60).mul(60);
  }

  function _ensureValidLoanDays(PlotOwner memory _owner, uint256 _numDays)
    private
    view
  {
    uint256 _maxNumDays = _owner.overrideMaxLoanDurationDays > 0
      ? _owner.overrideMaxLoanDurationDays
      : maxLoanDurationDays;
    require(
      _numDays <= _maxNumDays,
      'You cannot loan this plot for this long.'
    );
  }

  function _ensureValidLoanCharge(PlotOwner memory _owner, uint256 _numDays)
    private
    view
  {
    uint256 _perDayCharge = _owner.overrideMinLoanChargePerDay > 0
      ? _owner.overrideMinLoanChargePerDay
      : minLoanChargePerDay;
    uint256 _loanCharge = _perDayCharge.mul(_numDays);
    require(
      msg.value >= _loanCharge,
      'Make sure you send the appropriate amount of ETH to process your loan.'
    );
  }
}
