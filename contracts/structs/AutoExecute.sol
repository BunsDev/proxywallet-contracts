//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

struct AutoExecute {
    bytes32 id;
    address creator;
    address callback;
    bytes executeData;
    address executeTo;
    uint256 executeValue;
    uint256 executeAfter;
}
