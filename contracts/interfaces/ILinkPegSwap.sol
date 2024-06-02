// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILinkPegSwap {
    function swap(uint256 amount, address source, address target) external;
}
