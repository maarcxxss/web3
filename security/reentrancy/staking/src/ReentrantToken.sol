// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "./IERC20.sol";
import {IReentrancyReceiver} from "./IReentrancyReceiver.sol";

// Custom Errors
error InvalidAddress();

/// @title ReentrantToken
/// @notice ERC-20-like token with an intentionally malicious callback.
/// @dev Educational contract for demonstrating reentrancy.
///      Do not use in production.
contract ReentrantToken is IERC20 {
    // =============================================================
    // STATE VARIABLES
    // =============================================================

    // ERC-20 supply and balances.
    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;

    // ERC-20 spending allowances.
    mapping(address => mapping(address => uint256)) public override allowance;

    // Enables the malicious callback in transfer().
    bool public attack;

    // =============================================================
    // CONSTRUCTOR
    // =============================================================

    constructor(uint256 initialSupply) {
        totalSupply = initialSupply;
        balanceOf[msg.sender] = initialSupply;

        emit Transfer(address(0), msg.sender, initialSupply);
    }

    // =============================================================
    // ERC-20 FUNCTIONS
    // =============================================================

    /// @notice Approves a spender to transfer tokens on behalf of the caller.
    function approve(address spender, uint256 value) external override returns (bool) {
        if (spender == address(0)) {
            revert InvalidAddress();
        }

        allowance[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);

        return true;
    }

    /// @notice Transfers tokens from the caller to the recipient.
    /// @dev Intentionally invokes recipient code after updating balances.
    ///      This callback enables the reentrancy scenario.
    function transfer(address to, uint256 value) external override returns (bool) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");

        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;

        emit Transfer(msg.sender, to, value);

        // INTENTIONALLY MALICIOUS:
        // The recipient can execute code during the transfer.
        if (attack && to != address(0)) {
            IReentrancyReceiver(to).onTokenReceived();
        }

        return true;
    }

    /// @notice Transfers tokens using an existing allowance.
    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Insufficient allowance");

        allowance[from][msg.sender] -= value;
        balanceOf[from] -= value;
        balanceOf[to] += value;

        emit Transfer(from, to, value);

        return true;
    }

    // =============================================================
    // ATTACK CONFIGURATION
    // =============================================================

    /// @notice Enables the malicious callback in transfer().
    /// @dev Does not initiate an attack by itself.
    function startAttack() external {
        attack = true;
    }
}
