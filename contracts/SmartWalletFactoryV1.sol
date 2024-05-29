//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./SmartWalletV1.sol";

contract SmartWaletFactoryV1 {
    struct CreateParams {
        address linkToken;
        address clRegistrar;
        address clRegistry;
        address uniswapV3Router;
        address wethToken;
        bytes wethToLinkSwapPath;
        address[] initAllowlist;
    }

    address public immutable implementation;
    uint256 public counter;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    function createWallet(
        CreateParams calldata params
    ) external returns (address) {
        return create2Wallet(params, keccak256(abi.encodePacked(counter++)));
    }

    function create2Wallet(
        CreateParams calldata params,
        bytes32 salt
    ) public returns (address) {
        SmartWalletV1 wallet = SmartWalletV1(
            Clones.cloneDeterministic(implementation, salt)
        );
        wallet.initialize(
            msg.sender,
            params.linkToken,
            params.clRegistrar,
            params.clRegistry,
            params.uniswapV3Router,
            params.wethToken,
            params.wethToLinkSwapPath,
            params.initAllowlist
        );
        return address(wallet);
    }

    function predictCreate2Wallet(
        bytes32 salt
    ) external view returns (address) {
        return
            Clones.predictDeterministicAddress(
                implementation,
                salt,
                address(this)
            );
    }
}
