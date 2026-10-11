// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "./IERC20.sol";
import {IStaking} from "./IStaking.sol";

/// @title SecureStaking
/// @notice Staking contract that follows the Checks-Effects-Interactions pattern.
/// @dev Educational contract designed to prevent the reentrancy attack
///      demonstrated in VulnerableStaking.sol.
contract SecureStaking is IStaking {
    // =============================================================
    // STATE VARIABLES
    // =============================================================

    // ERC-20 token used for deposits and withdrawals.
    IERC20 public token;

    // Recorded staking balance for each user.
    mapping(address => uint256) public override balances;

    // =============================================================
    // CONSTRUCTOR
    // =============================================================

    /// @param tokenAddress Address of the ERC-20 token contract.
    constructor(address tokenAddress) {
        token = IERC20(tokenAddress);
    }

    // =============================================================
    // STAKING FUNCTIONS
    // =============================================================

    /// @notice Deposits tokens into the staking contract.
    /// @param amount Number of tokens to deposit.
    function deposit(uint256 amount) external override {
        require(amount > 0, "Amount must be greater than zero");

        bool success = token.transferFrom(msg.sender, address(this), amount);

        require(success, "Transfer failed");

        balances[msg.sender] += amount;
    }

    /// @notice Withdraws the caller's entire recorded balance.
    /// @dev Follows Checks-Effects-Interactions (CEI):
    ///      the balance is cleared before the external token call.
    function withdrawAll() external override {
        // CHECKS: read and validate the user's recorded balance.
        uint256 amount = balances[msg.sender];

        require(amount > 0, "Nothing to withdraw");

        // EFFECTS: update the state before interacting externally.
        balances[msg.sender] = 0;

        // INTERACTIONS: transfer tokens after updating the state.
        bool success = token.transfer(msg.sender, amount);

        require(success, "Transfer failed");
    }
}
