//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

struct CreateWalletParams {
    address owner;
    address allowlistOperator;
    address linkToken;
    address clRegistrar;
    address clRegistry;
    address uniswapV3Router;
    address wethToken;
    bytes wethToLinkSwapPath;
    address[] initAllowlist;
}
