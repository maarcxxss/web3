// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

import {VulnerableStaking} from "../src/VulnerableStaking.sol";
import {SecureStaking} from "../src/SecureStaking.sol";
import {ReentrantToken} from "../src/ReentrantToken.sol";
import {ReentrancyAttacker} from "../src/ReentrancyAttacker.sol";

/// @title ReentrancyTest
/// @notice Tests the reentrancy vulnerability and its mitigation.
/// @dev Uses a malicious token to trigger a callback during transfers.
contract ReentrancyTest is Test {
    // =============================================================
    // CONSTANTS
    // =============================================================

    uint256 constant INITIAL_SUPPLY = 1000;
    uint256 constant DEPOSIT_AMOUNT = 100;

    // =============================================================
    // CONTRACTS
    // =============================================================

    ReentrantToken token;
    VulnerableStaking vulnerableStaking;
    SecureStaking secureStaking;

    // =============================================================
    // ATTACKERS
    // =============================================================

    ReentrancyAttacker vulnerableAttacker;
    ReentrancyAttacker secureAttacker;

    // =============================================================
    // TEST ACTORS
    // =============================================================

    address victim;

    // =============================================================
    // SETUP
    // =============================================================

    /// @notice Deploys the token, staking contracts and attackers.
    function setUp() public {
        token = new ReentrantToken(INITIAL_SUPPLY);

        vulnerableStaking = new VulnerableStaking(address(token));
        secureStaking = new SecureStaking(address(token));

        vulnerableAttacker = new ReentrancyAttacker(address(token), address(vulnerableStaking));

        secureAttacker = new ReentrancyAttacker(address(token), address(secureStaking));

        victim = makeAddr("victim");
    }

    // =============================================================
    // SCENARIO PREPARATION
    // =============================================================

    /// @dev Prepares the vulnerable staking contract with two deposits.
    function _prepareVulnerableScenario() internal {
        // The victim deposits tokens.
        token.transfer(victim, DEPOSIT_AMOUNT);

        vm.prank(victim);
        token.approve(address(vulnerableStaking), DEPOSIT_AMOUNT);

        vm.prank(victim);
        vulnerableStaking.deposit(DEPOSIT_AMOUNT);

        // The attacker deposits the same amount.
        token.transfer(address(vulnerableAttacker), DEPOSIT_AMOUNT);
        vulnerableAttacker.deposit(DEPOSIT_AMOUNT);

        // Both deposits are held by the staking contract.
        assertEq(token.balanceOf(address(vulnerableStaking)), 2 * DEPOSIT_AMOUNT);

        assertEq(vulnerableStaking.balances(victim), DEPOSIT_AMOUNT);

        assertEq(vulnerableStaking.balances(address(vulnerableAttacker)), DEPOSIT_AMOUNT);
    }

    /// @dev Prepares the secure staking contract with two deposits.
    function _prepareSecureScenario() internal {
        // The victim deposits tokens.
        token.transfer(victim, DEPOSIT_AMOUNT);

        vm.prank(victim);
        token.approve(address(secureStaking), DEPOSIT_AMOUNT);

        vm.prank(victim);
        secureStaking.deposit(DEPOSIT_AMOUNT);

        // The attacker deposits the same amount.
        token.transfer(address(secureAttacker), DEPOSIT_AMOUNT);
        secureAttacker.deposit(DEPOSIT_AMOUNT);

        // Both deposits are held by the staking contract.
        assertEq(token.balanceOf(address(secureStaking)), 2 * DEPOSIT_AMOUNT);

        assertEq(secureStaking.balances(victim), DEPOSIT_AMOUNT);

        assertEq(secureStaking.balances(address(secureAttacker)), DEPOSIT_AMOUNT);
    }

    // =============================================================
    // 01. INITIALIZATION TEST
    // =============================================================

    /// @notice Verifies the initial token distribution.
    function test_SetUp() public view {
        assertEq(token.balanceOf(address(this)), INITIAL_SUPPLY);

        assertEq(token.balanceOf(address(vulnerableStaking)), 0);
        assertEq(token.balanceOf(address(secureStaking)), 0);

        assertEq(token.balanceOf(address(vulnerableAttacker)), 0);
        assertEq(token.balanceOf(address(secureAttacker)), 0);
    }

    // =============================================================
    // 02. REENTRANCY ATTACK - VULNERABLE CONTRACT
    // =============================================================

    /// @notice Demonstrates that reentrancy drains both deposits.
    function test_ReentrancyAttack() public {
        _prepareVulnerableScenario();

        // Enable the malicious token callback.
        token.startAttack();

        // Start the attack.
        vulnerableAttacker.attack();

        // The attacker withdraws both deposits.
        assertEq(token.balanceOf(address(vulnerableAttacker)), 2 * DEPOSIT_AMOUNT);

        assertEq(token.balanceOf(address(vulnerableStaking)), 0);

        // The attacker's recorded balance is cleared after reentrancy.
        assertEq(vulnerableStaking.balances(address(vulnerableAttacker)), 0);

        // The victim's recorded balance remains, but the tokens are gone.
        assertEq(vulnerableStaking.balances(victim), DEPOSIT_AMOUNT);
    }

    // =============================================================
    // 03. REENTRANCY ATTACK - PROTECTED CONTRACT
    // =============================================================

    /// @notice Verifies that the secure contract blocks the attack.
    function test_ReentrancyAttackBlocked() public {
        _prepareSecureScenario();

        // Enable the malicious token callback.
        token.startAttack();

        // The reentrant withdrawal finds a zero recorded balance.
        vm.expectRevert(bytes("Nothing to withdraw"));
        secureAttacker.attack();

        // The entire transaction reverts, including the first transfer.
        assertEq(token.balanceOf(address(secureAttacker)), 0);

        assertEq(token.balanceOf(address(secureStaking)), 2 * DEPOSIT_AMOUNT);

        // Both deposits remain recorded.
        assertEq(secureStaking.balances(address(secureAttacker)), DEPOSIT_AMOUNT);

        assertEq(secureStaking.balances(victim), DEPOSIT_AMOUNT);
    }
}