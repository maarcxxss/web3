// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "./IERC20.sol";
import {IStaking} from "./IStaking.sol";

// =============================================================
// ERRORS
// =============================================================

/// @title VulnerableStaking
/// @notice Staking contract intentionally vulnerable to reentrancy.
/// @dev Educational contract for reproducing a reentrancy attack.
///      Do not use in production.
contract VulnerableStaking is IStaking {
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
    /// @dev Intentionally vulnerable: the external token call occurs
    ///      before the user's recorded balance is cleared.
    function withdrawAll() external override {
        uint256 amount = balances[msg.sender];

        require(amount > 0, "Nothing to withdraw");

        // INTERACTION: the token may execute malicious recipient code.
        token.transfer(msg.sender, amount);

        // EFFECT: this update happens too late to prevent reentrancy.
        balances[msg.sender] = 0;
    }
}
