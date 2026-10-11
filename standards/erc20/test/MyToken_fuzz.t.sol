// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

import {MyToken, InsufficientBalance, InsufficientAllowance, CapExceeded} from "../src/MyToken.sol";

contract MyTokenFuzzTest is Test {
    // =============================================================
    // CONSTANTS
    // =============================================================

    uint256 private constant UNIT = 10 ** 18;
    uint256 private constant INITIAL_SUPPLY = 1000 * UNIT;

    // =============================================================
    // TEST ACCOUNTS
    // =============================================================

    address private owner = address(1);
    address private account2 = address(2);
    address private account3 = address(3);

    // =============================================================
    // CONTRACT UNDER TEST
    // =============================================================

    MyToken public token;

    // =============================================================
    // SETUP
    // =============================================================

    function setUp() public {
        vm.prank(owner);
        token = new MyToken(1000);
    }

    // =============================================================
    // 01. TRANSFER
    // =============================================================

    function testFuzz_Transfer(uint256 amount) public {
        amount = bound(amount, 0, INITIAL_SUPPLY);

        vm.prank(owner);
        token.transfer(account2, amount);

        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount);

        assertEq(token.balanceOf(account2), amount);

        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function testFuzz_TransferInsufficientBalance(uint256 amount) public {
        amount = bound(amount, INITIAL_SUPPLY + 1, INITIAL_SUPPLY * 2);

        vm.prank(owner);

        vm.expectRevert(abi.encodeWithSelector(InsufficientBalance.selector, INITIAL_SUPPLY, amount));

        token.transfer(account2, amount);
    }

    // =============================================================
    // 02. APPROVE
    // =============================================================

    function testFuzz_Approve(uint256 amount) public {
        vm.prank(owner);
        token.approve(account2, amount);

        assertEq(token.allowance(owner, account2), amount);
    }

    // =============================================================
    // 03. TRANSFERFROM
    // =============================================================

    function testFuzz_TransferFrom(uint256 amount) public {
        amount = bound(amount, 0, 300 * UNIT);

        vm.prank(owner);
        token.approve(account2, 300 * UNIT);

        vm.prank(account2);
        token.transferFrom(owner, account3, amount);

        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount);

        assertEq(token.balanceOf(account3), amount);

        assertEq(token.allowance(owner, account2), 300 * UNIT - amount);

        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function testFuzz_TransferFromInsufficientAllowance(uint256 amount) public {
        uint256 approvedAmount = 300 * UNIT;

        amount = bound(amount, approvedAmount + 1, 400 * UNIT);

        vm.prank(owner);
        token.approve(account2, approvedAmount);

        vm.prank(account2);

        vm.expectRevert(abi.encodeWithSelector(InsufficientAllowance.selector, approvedAmount, amount));

        token.transferFrom(owner, account3, amount);
    }

    // =============================================================
    // 04. MINT
    // =============================================================

    function testFuzz_Mint(uint256 amount) public {
        uint256 available = token.CAP() - token.totalSupply();
        amount = bound(amount, 0, available);

        vm.prank(owner);
        token.mint(account2, amount);

        assertEq(token.balanceOf(account2), amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + amount);
        assertLe(token.totalSupply(), token.CAP());
    }

    function testFuzz_MintCapExceeded(uint256 amount) public {
        uint256 available = token.CAP() - token.totalSupply();

        amount = bound(amount, available + 1, token.CAP());

        vm.prank(owner);

        vm.expectRevert(abi.encodeWithSelector(CapExceeded.selector, amount, available));

        token.mint(account2, amount);
    }

    // =============================================================
    // 05. BURN
    // =============================================================

    function testFuzz_Burn(uint256 amount) public {
        amount = bound(amount, 0, INITIAL_SUPPLY);

        vm.prank(owner);
        token.burn(amount);

        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount);

        assertEq(token.totalSupply(), INITIAL_SUPPLY - amount);

        assertEq(token.balanceOf(account2), 0);
    }
}
