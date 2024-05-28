//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./SmartWalletV1.sol";

contract SmartWaletFactoryV1 {
    address public immutable implementation;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    function createWallet(
        address[] calldata initAllowlist
    ) external returns (address) {
        SmartWalletV1 wallet = SmartWalletV1(Clones.clone(implementation));
        wallet.initialize(msg.sender, initAllowlist);
        return address(wallet);
    }

    function create2Wallet(
        address[] calldata initAllowlist,
        bytes32 salt
    ) external returns (address) {
        SmartWalletV1 wallet = SmartWalletV1(
            Clones.cloneDeterministic(implementation, salt)
        );
        wallet.initialize(msg.sender, initAllowlist);
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
