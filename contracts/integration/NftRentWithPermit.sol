//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

import "./NftRent.sol";

contract NftRentWithPermit is NftRent {
    constructor(address _smartWalletFactory) NftRent(_smartWalletFactory) {}

    function rentExternalWithPermit(
        bytes32 id,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        ISmartWallet(msg.sender).addToAllowlistWithPermit(
            address(this),
            deadline,
            v,
            r,
            s
        );
        _rent(id, msg.sender);
    }
}
