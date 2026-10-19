// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol";
import {Staking} from "../src/Staking.sol";

/// @title StakingHandler
/// @notice Exposes bounded actions for Foundry to generate staking usage sequences.
contract StakingHandler is Test {
    // =============================================================
    // CONSTANTS
    // =============================================================

    uint256 private constant UNIT = 1e18;
    uint256 private constant INITIAL_SUPPLY = 1000 * UNIT;
    uint256 private constant INITIAL_USER_BALANCE = 100 * UNIT;

    // =============================================================
    // CONTRACTS AND TEST ACCOUNTS
    // =============================================================

    MyToken public token;
    MyToken public rewardToken;
    Staking public staking;

    address public marta = makeAddr("invariant-marta");
    address public marcos = makeAddr("invariant-marcos");

    // =============================================================
    // SETUP
    // =============================================================

    constructor() {
        token = new MyToken(INITIAL_SUPPLY / UNIT);
        rewardToken = new MyToken(INITIAL_SUPPLY / UNIT);
        staking = new Staking(address(token), address(rewardToken));

        token.transfer(marta, INITIAL_USER_BALANCE);
        token.transfer(marcos, INITIAL_USER_BALANCE);
        token.approve(address(staking), type(uint256).max);
        rewardToken.approve(address(staking), type(uint256).max);
    }

    // =============================================================
    // HANDLER ACTIONS
    // =============================================================

    /// @notice Stakes a valid amount on behalf of one of the test users.
    function stake(uint256 userSeed, uint256 amountSeed) external {
        address user = _user(userSeed);
        uint256 walletBalance = token.balanceOf(user);
        if (walletBalance == 0) return;

        uint256 amount = bound(amountSeed, 1, walletBalance);
        vm.startPrank(user);
        token.approve(address(staking), amount);
        staking.stake(amount);
        vm.stopPrank();
    }

    /// @notice Withdraws up to the selected user's current staked balance.
    function withdraw(uint256 userSeed, uint256 amountSeed) external {
        address user = _user(userSeed);
        uint256 staked = staking.stakedBalance(user);
        if (staked == 0) return;

        uint256 amount = bound(amountSeed, 1, staked);
        vm.prank(user);
        staking.withdraw(amount);
    }

    /// @notice Attempts to claim rewards for one of the test users.
    function claim(uint256 userSeed) external {
        vm.prank(_user(userSeed));
        staking.getReward();
    }

    /// @notice Starts a reward period after the previous one ends, if enough funds remain.
    function fundRewards(uint256 amountSeed) external {
        if (block.timestamp < staking.periodFinish()) return;

        uint256 available = rewardToken.balanceOf(address(this));
        uint256 minimumFunding = staking.rewardsDuration();
        if (available < minimumFunding) return;

        uint256 amount = bound(amountSeed, minimumFunding, available);
        staking.fundRewards(amount);
    }

    /// @notice Advances time to exercise reward accounting across a period.
    function advanceTime(uint256 timeSeed) external {
        uint256 elapsed = bound(timeSeed, 1, 30 days);
        vm.warp(block.timestamp + elapsed);
    }

    /// @dev Alternates between Marta and Marcos to keep the participant set bounded.
    function _user(uint256 seed) private view returns (address) {
        return seed % 2 == 0 ? marta : marcos;
    }
}

/// @title StakingInvariantTest
/// @notice Checks properties that must hold after sequences of handler actions.
contract StakingInvariantTest is Test {
    // =============================================================
    // CONTRACTS UNDER TEST
    // =============================================================

    StakingHandler private handler;
    Staking private staking;
    MyToken private token;
    MyToken private rewardToken;

    // =============================================================
    // SETUP
    // =============================================================

    function setUp() public {
        handler = new StakingHandler();
        staking = handler.staking();
        token = handler.token();
        rewardToken = handler.rewardToken();

        targetContract(address(handler));
    }

    // =============================================================
    // 01. PRINCIPAL ACCOUNTING
    // =============================================================

    /// @notice The recorded total matches user balances and is backed by the staking tokens.
    function invariant_TotalStakeMatchesUsersAndTokenBalance() public view {
        uint256 usersStake = staking.stakedBalance(handler.marta()) + staking.stakedBalance(handler.marcos());

        assertEq(staking.totalStaked(), usersStake);
        assertGe(token.balanceOf(address(staking)), staking.totalStaked());
    }

    // =============================================================
    // 02. REWARD RESERVE ACCOUNTING
    // =============================================================

    /// @notice The reward token balance backs the reserve, which covers users' accrued debt.
    function invariant_RewardReserveRemainsBackedAndCoversDebt() public view {
        uint256 usersDebt = staking.earned(handler.marta()) + staking.earned(handler.marcos());

        assertGe(rewardToken.balanceOf(address(staking)), staking.reservedRewards());
        assertGe(staking.reservedRewards(), usersDebt);
    }
}
