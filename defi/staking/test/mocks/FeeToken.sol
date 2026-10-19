// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "../../src/IERC20.sol";

contract FeeToken is IERC20 {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public constant FEE_PERCENT = 2;

    constructor(uint256 initialSupply) {
        totalSupply = initialSupply;
        balanceOf[msg.sender] = initialSupply;
        emit Transfer(address(0), msg.sender, initialSupply);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");

        allowance[from][msg.sender] -= amount;
        emit Approval(from, msg.sender, allowance[from][msg.sender]);

        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "Invalid recipient");
        require(balanceOf[from] >= amount, "Insufficient balance");

        uint256 fee = amount * FEE_PERCENT / 100;
        uint256 received = amount - fee;

        balanceOf[from] -= amount;
        balanceOf[to] += received;
        totalSupply -= fee;

        emit Transfer(from, to, received);
        if (fee > 0) {
            emit Transfer(from, address(0), fee);
        }
    }
}
