// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

contract GasInfo {
  uint256 inc;
  event Inc(
    uint256 gasPriceBefore,
    uint256 gasLeftBefore,
    uint256 gasPriceAfter,
    uint256 gasLeftAfter
  );

  function getGasLeft() external view returns (uint256, uint256) {
    return (tx.gasprice, gasleft());
  }

  function increase() external {
    uint256 gpb = tx.gasprice;
    uint256 glb = gasleft();
    inc++;
    uint256 gpa = tx.gasprice;
    uint256 gla = gasleft();
    emit Inc(gpb, glb, gpa, gla);
  }
}
