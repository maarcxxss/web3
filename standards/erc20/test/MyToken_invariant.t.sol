// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol";

contract MyTokenHandler is Test {
    // =============================================================
    // CONTRACT UNDER TEST
    // =============================================================

    MyToken internal token;

    // =============================================================
    // TEST ACCOUNTS
    // =============================================================

    address[] internal accounts;

    // =============================================================
    // CONSTRUCTOR
    // =============================================================

    constructor(MyToken _token, address _owner, address _account2, address _account3) {
        token = _token;

        accounts.push(_owner);
        accounts.push(_account2);
        accounts.push(_account3);
    }

    // =============================================================
    // HANDLER ACTIONS
    // =============================================================

    function transfer(uint256 amount, uint256 fromIndex, uint256 toIndex) public {
        fromIndex = bound(fromIndex, 0, accounts.length - 1);
        toIndex = bound(toIndex, 0, accounts.length - 1);

        address from = accounts[fromIndex];
        address to = accounts[toIndex];

        amount = bound(amount, 0, token.balanceOf(from));

        vm.prank(from);
        token.transfer(to, amount);
    }
}

contract MyTokenInvariantTest is Test {
    // =============================================================
    // CONSTANTS
    // =============================================================

    uint256 private constant INITIAL_SUPPLY = 1000 * 10 ** 18;

    // =============================================================
    // TEST ACCOUNTS
    // =============================================================

    address private owner = address(1);
    address private account2 = address(2);
    address private account3 = address(3);

    // =============================================================
    // CONTRACTS
    // =============================================================

    MyToken private token;
    MyTokenHandler private handler;

    // =============================================================
    // SETUP
    // =============================================================

    function setUp() public {
        vm.prank(owner);
        token = new MyToken(1000);

        handler = new MyTokenHandler(token, owner, account2, account3);

        targetContract(address(handler));
    }

    // =============================================================
    // INVARIANTS
    // =============================================================

    function invariant_TotalSupplyRemainsConstant() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function invariant_TotalSupplyEqualsBalances() public view {
        uint256 totalBalances = token.balanceOf(owner) + token.balanceOf(account2) + token.balanceOf(account3);

        assertEq(totalBalances, token.totalSupply());
    }
}
