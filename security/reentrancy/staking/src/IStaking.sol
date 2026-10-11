// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IStaking {
    function deposit(uint256 amount) external;
    function withdrawAll() external;
    function balances(address account) external view returns (uint256);
}
