// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Lock {
    uint256 public unlockTime;
    address public owner;

    event Withdrawal(address indexed to, uint256 amount);

    constructor(uint256 _unlockTime) payable {
        require(
            _unlockTime > block.timestamp,
            "Unlock time should be in the future"
        );
        unlockTime = _unlockTime;
        owner = msg.sender;
    }

    function withdraw() public {
        require(block.timestamp >= unlockTime, "You can't withdraw yet");
        require(msg.sender == owner, "You aren't the owner");

        uint256 amount = address(this).balance;
        payable(owner).transfer(amount);

        emit Withdrawal(owner, amount);
    }
}
