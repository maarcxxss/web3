// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "./IERC20.sol";

abstract contract MyToken is IERC20 {

    uint256 public override totalSupply;

    mapping(address => uint256) public override balanceOf;

    constructor(uint256 initialSupply) {

        totalSupply = initialSupply;

        balanceOf[msg.sender] = initialSupply;

        emit Transfer(address(0), msg.sender, initialSupply);
    }
}