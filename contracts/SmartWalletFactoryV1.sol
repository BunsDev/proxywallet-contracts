//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./SmartWalletV1.sol";
import "./structs/CreateWalletParams.sol";

contract SmartWalletFactoryV1 {
    address public immutable implementation;
    uint256 public counter;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    function createWallet(
        CreateWalletParams calldata params
    ) external returns (address) {
        return create2Wallet(params, keccak256(abi.encodePacked(counter++)));
    }

    function create2Wallet(
        CreateWalletParams calldata params,
        bytes32 salt
    ) public returns (address) {
        SmartWalletV1 wallet = SmartWalletV1(
            payable(Clones.cloneDeterministic(implementation, salt))
        );
        wallet.initialize(params);
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
