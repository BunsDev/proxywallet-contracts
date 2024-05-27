// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

contract Lock {
    uint256 public unlockTime;
    address payable public owner;

    event Withdrawal(uint256 amount, uint256 when);

    error UnlockTimeInPast();
    error NotOwner();
    error TooEarly();

    constructor(uint256 _unlockTime) payable {
        if (_unlockTime < block.timestamp) {
            revert UnlockTimeInPast();
        }

        unlockTime = _unlockTime;
        owner = payable(msg.sender);
    }

    function withdraw() public {
        if (block.timestamp < unlockTime) {
            revert TooEarly();
        }
        if (msg.sender != owner) {
            revert NotOwner();
        }

        emit Withdrawal(address(this).balance, block.timestamp);

        owner.transfer(address(this).balance);
    }
}
