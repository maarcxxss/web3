// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol";
import {FeeToken} from "./mocks/FeeToken.sol";
import {Staking} from "../src/Staking.sol";
import {IStaking} from "../src/IStaking.sol";
import {CoverageERC20} from "./mocks/CoverageERC20.sol";

contract StakingTest is Test {
    // =============================================================
    // CONSTANTS
    // =============================================================

    uint256 private constant UNIT = 10 ** 18;
    uint256 private constant INITIAL_SUPPLY = 1000 * UNIT;

    // =============================================================
    // TEST ACCOUNTS
    // =============================================================

    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");

    // =============================================================
    // CONTRACTS UNDER TEST
    // =============================================================

    MyToken private token;
    MyToken private rewardToken;
    Staking private staking;

    // =============================================================
    // SETUP
    // =============================================================

    function setUp() public {
        token = new MyToken(INITIAL_SUPPLY / UNIT);
        rewardToken = new MyToken(INITIAL_SUPPLY / UNIT);
        staking = new Staking(address(token), address(rewardToken));

        token.transfer(alice, 100 * UNIT);
        token.transfer(bob, 100 * UNIT);
    }

    // =============================================================
    // 01. INITIAL STATE
    // =============================================================

    function test_InitialState() public view {
        assertEq(staking.owner(), address(this));
        assertEq(address(staking.token()), address(token));
        assertEq(address(staking.rewardsToken()), address(rewardToken));
        assertEq(staking.totalStaked(), 0);
        assertEq(staking.reservedRewards(), 0);
        assertEq(staking.rewardRate(), 0);
        assertEq(staking.rewardsDuration(), 7 days);
        assertEq(staking.stakedBalance(alice), 0);
        assertEq(staking.stakedBalance(bob), 0);
    }

    // =============================================================
    // 02. CONSTRUCTOR
    // =============================================================

    function test_RevertDeployWithZeroTokenAddress() public {
        vm.expectRevert(IStaking.InvalidStakingTokenAddress.selector);
        new Staking(address(0), address(rewardToken));
    }

    function test_RevertDeployWithNonContractStakingToken() public {
        vm.expectRevert(IStaking.StakingTokenHasNoCode.selector);
        new Staking(address(1), address(rewardToken));
    }

    function test_RevertDeployWithZeroRewardsTokenAddress() public {
        vm.expectRevert(IStaking.InvalidRewardsTokenAddress.selector);
        new Staking(address(token), address(0));
    }

    function test_RevertDeployWithNonContractRewardsToken() public {
        vm.expectRevert(IStaking.RewardsTokenHasNoCode.selector);
        new Staking(address(token), address(1));
    }

    // =============================================================
    // 03. STAKING
    // =============================================================

    /* --- Successful operations --- */

    function test_Stake() public {
        vm.startPrank(alice);
        token.approve(address(staking), 50 * UNIT);
        staking.stake(50 * UNIT);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), 50 * UNIT);
        assertEq(token.balanceOf(address(staking)), 50 * UNIT);
        assertEq(staking.stakedBalance(alice), 50 * UNIT);
    }

    function test_MultipleUsers() public {
        // Alice hace stake de 50
        vm.startPrank(alice);
        token.approve(address(staking), 50 * UNIT);
        staking.stake(50 * UNIT);
        vm.stopPrank();

        // Bob hace stake de 30
        vm.startPrank(bob);
        token.approve(address(staking), 30 * UNIT);
        staking.stake(30 * UNIT);
        vm.stopPrank();

        // Comprobamos los balances individuales
        assertEq(staking.stakedBalance(alice), 50 * UNIT);
        assertEq(staking.stakedBalance(bob), 30 * UNIT);

        // El contrato posee 80 MTO en total
        assertEq(token.balanceOf(address(staking)), 80 * UNIT);
    }

    /* --- Reverts --- */

    function test_RevertStakeZero() public {
        vm.expectRevert(IStaking.AmountMustBeGreaterThanZero.selector);

        vm.prank(alice);
        staking.stake(0);
    }

    function test_RevertStakeWithoutApproval() public {
        vm.expectRevert();

        vm.prank(alice);
        staking.stake(50 * UNIT);
    }

    function test_RevertStakeMoreThanWalletBalance() public {
        vm.startPrank(alice);
        token.approve(address(staking), 101 * UNIT);
        vm.expectRevert();
        staking.stake(101 * UNIT);
        vm.stopPrank();
    }

    function test_RevertStakeWithFeeToken() public {
        FeeToken feeToken = new FeeToken(1000 * UNIT);
        Staking feeStaking = new Staking(address(feeToken), address(rewardToken));
        address aliceFee = makeAddr("aliceFee");
        feeToken.transfer(aliceFee, 200 * UNIT);
        vm.startPrank(aliceFee);
        feeToken.approve(address(feeStaking), 100 * UNIT);
        vm.expectRevert(abi.encodeWithSelector(IStaking.UnexpectedAmountReceived.selector, 100 * UNIT, 98 * UNIT));
        feeStaking.stake(100 * UNIT);
        vm.stopPrank();

        assertEq(feeStaking.stakedBalance(aliceFee), 0);
        assertEq(feeStaking.totalStaked(), 0);
        assertEq(feeToken.balanceOf(address(feeStaking)), 0);
    }

    function test_RevertStakeWhenTokenTransferFromReturnsFalse() public {
        CoverageERC20 coverageToken = new CoverageERC20(100 * UNIT);
        Staking coverageStaking = new Staking(address(coverageToken), address(rewardToken));
        coverageToken.transfer(alice, 10 * UNIT);
        coverageToken.setTransferFromReturns(false);

        vm.startPrank(alice);
        coverageToken.approve(address(coverageStaking), UNIT);
        vm.expectRevert(IStaking.StakingTokenTransferFailed.selector);
        coverageStaking.stake(UNIT);
        vm.stopPrank();

        assertEq(coverageStaking.stakedBalance(alice), 0);
        assertEq(coverageStaking.totalStaked(), 0);
    }

    function test_RevertOnReentrantStake() public {
        CoverageERC20 coverageToken = new CoverageERC20(100 * UNIT);
        Staking coverageStaking = new Staking(address(coverageToken), address(rewardToken));
        coverageToken.transfer(alice, 10 * UNIT);
        coverageToken.setCallback(address(coverageStaking), abi.encodeCall(Staking.stake, (UNIT)), false);

        vm.startPrank(alice);
        coverageToken.approve(address(coverageStaking), UNIT);
        coverageStaking.stake(UNIT);
        vm.stopPrank();

        bytes memory callbackRevert = coverageToken.callbackReturndata();
        bytes4 callbackError;
        assembly ("memory-safe") {
            callbackError := mload(add(callbackRevert, 32))
        }
        assertFalse(coverageToken.callbackSucceeded());
        assertEq(callbackError, IStaking.ReentrantCall.selector);
        assertEq(coverageStaking.stakedBalance(alice), UNIT);
        assertEq(coverageStaking.totalStaked(), UNIT);
    }

    // =============================================================
    // 04. WITHDRAWALS
    // =============================================================

    /* --- Successful operations --- */

    function test_Withdraw() public {
        vm.startPrank(alice);
        token.approve(address(staking), 50 * UNIT);
        staking.stake(50 * UNIT);
        staking.withdraw(20 * UNIT);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), 70 * UNIT);
        assertEq(token.balanceOf(address(staking)), 30 * UNIT);
        assertEq(staking.stakedBalance(alice), 30 * UNIT);
    }

    function test_WithdrawDoesNotAffectOtherUsers() public {
        // Alice hace stake de 50 tokens
        vm.startPrank(alice);
        token.approve(address(staking), 50 * UNIT);
        staking.stake(50 * UNIT);
        vm.stopPrank();

        // Bob hace stake de 30 tokens
        vm.startPrank(bob);
        token.approve(address(staking), 30 * UNIT);
        staking.stake(30 * UNIT);
        vm.stopPrank();

        // Alice retira 20 tokens
        vm.startPrank(alice);
        staking.withdraw(20 * UNIT);
        vm.stopPrank();

        // Comprobamos los balances internos
        assertEq(staking.stakedBalance(alice), 30 * UNIT);
        assertEq(staking.stakedBalance(bob), 30 * UNIT);

        // Comprobamos los tokens reales que tiene Staking
        assertEq(token.balanceOf(address(staking)), 60 * UNIT);

        // Comprobacion para contabilizar que el total staked es a la suma de los usuarios que tienen en el contrato de staking (30+30)
        assertEq(staking.totalStaked(), 60 * UNIT);

        // Comprobacion para comprobar que el total staked es igual al balance de tokens en el ERC-20
        assertEq(staking.totalStaked(), token.balanceOf(address(staking)));
    }

    function test_WithdrawEntireStake() public {
        uint256 amount = 50 * UNIT;

        vm.startPrank(alice);
        token.approve(address(staking), amount);
        staking.stake(amount);
        staking.withdraw(amount);
        vm.stopPrank();

        assertEq(staking.stakedBalance(alice), 0);
        assertEq(staking.totalStaked(), 0);
        assertEq(token.balanceOf(address(staking)), 0);
        assertEq(token.balanceOf(alice), 100 * UNIT);
    }

    /* --- Reverts --- */

    function test_RevertWithdrawZero() public {
        vm.expectRevert(IStaking.AmountMustBeGreaterThanZero.selector);

        vm.prank(alice);
        staking.withdraw(0);
    }

    function test_RevertWithdrawMoreThanStaked() public {
        vm.startPrank(alice);
        token.approve(address(staking), 50 * UNIT);
        staking.stake(50 * UNIT);
        vm.expectRevert(abi.encodeWithSelector(IStaking.InsufficientStakedBalance.selector, 50 * UNIT, 60 * UNIT));
        staking.withdraw(60 * UNIT);
        vm.stopPrank();
    }

    function test_RevertWithdrawWithoutStake() public {
        vm.expectRevert(abi.encodeWithSelector(IStaking.InsufficientStakedBalance.selector, 0, 1));

        vm.prank(alice);
        staking.withdraw(1);
    }

    function test_RevertWithdrawWhenTokenTransferReturnsFalse() public {
        CoverageERC20 coverageToken = new CoverageERC20(100 * UNIT);
        Staking coverageStaking = new Staking(address(coverageToken), address(rewardToken));
        coverageToken.transfer(alice, 10 * UNIT);

        vm.startPrank(alice);
        coverageToken.approve(address(coverageStaking), 5 * UNIT);
        coverageStaking.stake(5 * UNIT);
        vm.stopPrank();

        coverageToken.setTransferReturns(false);
        vm.expectRevert(IStaking.StakingTokenTransferFailed.selector);
        vm.prank(alice);
        coverageStaking.withdraw(2 * UNIT);

        // El revert revierte también los cambios de estado previos a transfer.
        assertEq(coverageStaking.stakedBalance(alice), 5 * UNIT);
        assertEq(coverageStaking.totalStaked(), 5 * UNIT);
    }

    // =============================================================
    // 05. EVENTS
    // =============================================================

    /* --- Events --- */

    function test_StakeEmitsEvent() public {
        vm.startPrank(alice);
        token.approve(address(staking), 50 * UNIT);

        vm.expectEmit(true, false, false, true);
        emit IStaking.Staked(alice, 50 * UNIT);

        staking.stake(50 * UNIT);
        vm.stopPrank();
    }

    function test_WithdrawEmitsEvent() public {
        vm.startPrank(alice);
        token.approve(address(staking), 50 * UNIT);
        staking.stake(50 * UNIT);

        vm.expectEmit(true, false, false, true);
        emit IStaking.Withdrawn(alice, 20 * UNIT);

        staking.withdraw(20 * UNIT);
        vm.stopPrank();
    }

    // =============================================================
    // 06. REWARD FUNDING
    // =============================================================

    /* --- Successful operations --- */

    function test_FundRewards() public {
        uint256 amount = 700 * UNIT;

        rewardToken.approve(address(staking), amount);
        uint256 startTime = block.timestamp;
        staking.fundRewards(amount);

        assertEq(staking.rewardRate(), amount / staking.rewardsDuration());
        assertEq(staking.lastUpdateTime(), startTime);
        assertEq(staking.periodFinish(), startTime + staking.rewardsDuration());
        assertEq(staking.reservedRewards(), staking.rewardRate() * staking.rewardsDuration());
        assertEq(rewardToken.balanceOf(address(staking)), amount);
    }

    function test_RevertFundRewardsWhenTransferFromReturnsFalse() public {
        CoverageERC20 coverageRewardToken = new CoverageERC20(1000 * UNIT);
        Staking coverageStaking = new Staking(address(token), address(coverageRewardToken));
        coverageRewardToken.setTransferFromReturns(false);
        coverageRewardToken.approve(address(coverageStaking), 700 * UNIT);

        vm.expectRevert(IStaking.RewardsTokenTransferFailed.selector);
        coverageStaking.fundRewards(700 * UNIT);
    }

    function test_RevertFundRewardsWhenRewardRateIsZero() public {
        rewardToken.approve(address(staking), 1);

        vm.expectRevert(abi.encodeWithSelector(IStaking.RewardRateIsZero.selector, 1, staking.rewardsDuration()));
        staking.fundRewards(1);
    }

    function test_RevertFundRewardsWhenReserveIsInsufficient() public {
        uint256 firstFunding = 700 * UNIT;
        uint256 nextFunding = 200 * UNIT;
        uint256 stakeAmount = 100 * UNIT;

        rewardToken.approve(address(staking), firstFunding);
        staking.fundRewards(firstFunding);

        vm.startPrank(alice);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Alice permanece en staking durante todo el periodo y actualiza la contabilidad al retirarse.
        vm.warp(staking.periodFinish());
        vm.prank(alice);
        staking.withdraw(stakeAmount);

        uint256 previousReserve = staking.reservedRewards();
        assertGt(previousReserve, 0);
        assertEq(staking.periodRewardsGenerated(), previousReserve);

        // Simula una pérdida anómala de los fondos que respaldaban la reserva anterior.
        uint256 balanceToDrain = rewardToken.balanceOf(address(staking));
        vm.prank(address(staking));
        rewardToken.transfer(address(this), balanceToDrain);

        rewardToken.approve(address(staking), nextFunding);
        uint256 nextScheduled = (nextFunding / staking.rewardsDuration()) * staking.rewardsDuration();
        uint256 requiredBalance = previousReserve + nextScheduled;

        vm.expectRevert(
            abi.encodeWithSelector(IStaking.InsufficientRewardReserve.selector, nextFunding, requiredBalance)
        );
        staking.fundRewards(nextFunding);
    }

    /* --- Reverts --- */

    function test_RevertFundRewardsDuringActivePeriod() public {
        uint256 rewardAmount = 700 * UNIT;
        rewardToken.approve(address(staking), rewardAmount);
        staking.fundRewards(rewardAmount);

        vm.expectRevert(abi.encodeWithSelector(IStaking.RewardPeriodActive.selector, staking.periodFinish()));
        staking.fundRewards(1 * UNIT);
    }

    function test_RevertFundRewardsZero() public {
        vm.expectRevert(IStaking.AmountMustBeGreaterThanZero.selector);
        staking.fundRewards(0);
    }

    function test_RevertFundRewardsUnauthorized() public {
        vm.expectRevert(IStaking.NotOwner.selector);

        vm.prank(alice);
        staking.fundRewards(UNIT);
    }

    function test_RevertFundRewardsWithFeeToken() public {
        FeeToken feeRewardToken = new FeeToken(1000 * UNIT);
        Staking feeRewardStaking = new Staking(address(token), address(feeRewardToken));
        uint256 amount = 100 * UNIT;
        feeRewardToken.approve(address(feeRewardStaking), amount);

        vm.expectRevert(
            abi.encodeWithSelector(IStaking.UnexpectedAmountReceived.selector, amount, amount - (amount * 2 / 100))
        );
        feeRewardStaking.fundRewards(amount);

        assertEq(feeRewardToken.balanceOf(address(feeRewardStaking)), 0);
        assertEq(feeRewardStaking.reservedRewards(), 0);
    }

    function test_LastTimeRewardApplicableClampsAtPeriodFinish() public {
        assertEq(staking.lastTimeRewardApplicable(), 0);

        uint256 amount = 700 * UNIT;
        rewardToken.approve(address(staking), amount);
        uint256 startTime = block.timestamp;
        staking.fundRewards(amount);

        assertEq(staking.lastTimeRewardApplicable(), startTime);

        uint256 finishTime = staking.periodFinish();
        vm.warp(finishTime + 1);
        assertEq(staking.lastTimeRewardApplicable(), finishTime);
    }

    // =============================================================
    // 07. REWARD CALCULATION AND DISTRIBUTION
    // =============================================================

    /* --- Successful operations --- */

    function test_RewardsAreDistributedProportionally() public {
        uint256 rewardAmount = 700 * UNIT;
        uint256 aliceStake = 100 * UNIT;
        uint256 bobStake = 300 * UNIT;

        // Financiamos el periodo de recompensas.
        rewardToken.approve(address(staking), rewardAmount);
        staking.fundRewards(rewardAmount);

        // Bob necesita 200 tokens adicionales para depositar 300.
        token.transfer(bob, 200 * UNIT);

        // Alice deposita 100 tokens.
        vm.startPrank(alice);
        token.approve(address(staking), aliceStake);
        staking.stake(aliceStake);
        vm.stopPrank();

        // Bob deposita 300 tokens.
        vm.startPrank(bob);
        token.approve(address(staking), bobStake);
        staking.stake(bobStake);
        vm.stopPrank();

        // Avanzamos un día.
        uint256 elapsed = 1 days;
        vm.warp(block.timestamp + elapsed);

        // Calculamos la distribución esperada.
        uint256 totalRewards = staking.rewardRate() * elapsed;
        uint256 expectedAlice = totalRewards / 4;
        uint256 expectedBob = totalRewards * 3 / 4;

        assertApproxEqAbs(staking.earned(alice), expectedAlice, 1e12);
        assertApproxEqAbs(staking.earned(bob), expectedBob, 1e12);
    }

    function test_NoRewardsAccumulateWithoutStakers() public {
        uint256 rewardAmount = 700 * UNIT;
        rewardToken.approve(address(staking), rewardAmount);
        staking.fundRewards(rewardAmount);
        uint256 initialRewardPerToken = staking.rewardPerTokenStored();

        // Avanza un día sin que nadie deposite tokens.
        vm.warp(block.timestamp + 1 days);

        // El acumulado global no cambia porque no hay stake.
        assertEq(staking.rewardPerToken(), initialRewardPerToken);
    }

    function test_RewardsRespectDifferentEntryTimes() public {
        uint256 firstAmount = 700 * UNIT;
        uint256 stakeAmount = 100 * UNIT;

        // Financiar el periodo de recompensas.
        rewardToken.approve(address(staking), firstAmount);
        staking.fundRewards(firstAmount);

        // Día 0: Alice deposita 100 tokens.
        vm.startPrank(alice);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Día 1: transcurre un día.
        vm.warp(block.timestamp + 1 days);

        // Bob entra cuando Alice ya lleva un día participando.
        vm.startPrank(bob);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Día 2: ambos han participado durante tiempos distintos.
        vm.warp(block.timestamp + 1 days);
        uint256 aliceRewards = staking.earned(alice);
        uint256 bobRewards = staking.earned(bob);

        // Alice debe tener aproximadamente 150 tokens.
        assertApproxEqAbs(aliceRewards, 150 * UNIT, 10 ** 12);

        // Bob debe tener aproximadamente 50 tokens.
        assertApproxEqAbs(bobRewards, 50 * UNIT, 10 ** 12);

        // Alice debe haber ganado aproximadamente el triple.
        assertApproxEqAbs(aliceRewards, bobRewards * 3, 10 ** 12);
    }

    // =============================================================
    // 08. REWARD CLAIMS
    // =============================================================

    /* --- Successful operations --- */

    function test_GetRewardPaysEmitsAndReducesReserve() public {
        uint256 rewardAmount = 700 * UNIT;
        uint256 stakeAmount = 100 * UNIT;

        // Financiamos las recompensas.
        rewardToken.approve(address(staking), rewardAmount);
        staking.fundRewards(rewardAmount);

        // Alice deposita sus tokens.
        vm.startPrank(alice);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Dejamos que se acumulen recompensas.
        vm.warp(block.timestamp + 1 days);
        uint256 expectedReward = staking.earned(alice);
        uint256 balanceBefore = rewardToken.balanceOf(alice);
        uint256 reserveBefore = staking.reservedRewards();

        vm.expectEmit(true, false, false, true);
        emit IStaking.RewardPaid(alice, expectedReward);

        vm.prank(alice);
        staking.getReward();

        assertEq(rewardToken.balanceOf(alice), balanceBefore + expectedReward);
        assertEq(staking.reservedRewards(), reserveBefore - expectedReward);
        assertEq(staking.rewards(alice), 0);
        assertEq(staking.earned(alice), 0);
        assertEq(staking.stakedBalance(alice), stakeAmount);
        assertEq(token.balanceOf(address(staking)), stakeAmount);
    }

    function test_RevertGetRewardWhenTransferReturnsFalse() public {
        CoverageERC20 coverageRewardToken = new CoverageERC20(1000 * UNIT);
        Staking coverageStaking = new Staking(address(token), address(coverageRewardToken));
        uint256 rewardFunding = 700 * UNIT;
        uint256 stakeAmount = 100 * UNIT;

        coverageRewardToken.approve(address(coverageStaking), rewardFunding);
        coverageStaking.fundRewards(rewardFunding);

        vm.startPrank(alice);
        token.approve(address(coverageStaking), stakeAmount);
        coverageStaking.stake(stakeAmount);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        uint256 reserveBeforeClaim = coverageStaking.reservedRewards();
        assertGt(coverageStaking.earned(alice), 0);

        coverageRewardToken.setTransferReturns(false);
        vm.expectRevert(IStaking.RewardsTokenTransferFailed.selector);
        vm.prank(alice);
        coverageStaking.getReward();

        // La operación revertida no borra la deuda ni reduce la reserva.
        assertGt(coverageStaking.earned(alice), 0);
        assertEq(coverageStaking.reservedRewards(), reserveBeforeClaim);
    }

    function test_ClaimedRewardsAreNotReservedAgain() public {
        uint256 firstAmount = 700 * UNIT;
        uint256 stakeAmount = 100 * UNIT;

        // Financiar el primer periodo.
        rewardToken.approve(address(staking), firstAmount);
        staking.fundRewards(firstAmount);

        // Alice hace staking.
        vm.startPrank(alice);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Dejar que se acumulen recompensas.
        vm.warp(block.timestamp + 1 days);
        uint256 pendingRewards = staking.earned(alice);
        assertGt(pendingRewards, 0);
        uint256 reserveBeforeClaim = staking.reservedRewards();

        // Alice reclama las recompensas.
        vm.prank(alice);
        staking.getReward();

        // La reserva disminuye exactamente lo reclamado.
        assertEq(staking.reservedRewards(), reserveBeforeClaim - pendingRewards);
        uint256 balanceAfterFirstClaim = rewardToken.balanceOf(alice);
        assertEq(balanceAfterFirstClaim, pendingRewards);

        // Termina el primer periodo.
        vm.warp(staking.periodFinish());

        // Financiar el segundo periodo.
        uint256 secondAmount = 200 * UNIT;
        rewardToken.approve(address(staking), secondAmount);
        staking.fundRewards(secondAmount);
        uint256 pendingAfterFirstClaim = staking.earned(alice);
        assertGt(pendingAfterFirstClaim, 0);
        uint256 balanceBeforeSecondClaim = rewardToken.balanceOf(alice);
        vm.prank(alice);
        staking.getReward();
        assertEq(rewardToken.balanceOf(alice), balanceBeforeSecondClaim + pendingAfterFirstClaim);
        assertEq(staking.earned(alice), 0);

        // Una tercera reclamación no debe pagar nada adicional.
        uint256 balanceAfterSecondClaim = rewardToken.balanceOf(alice);
        vm.prank(alice);
        staking.getReward();

        assertEq(rewardToken.balanceOf(alice), balanceAfterSecondClaim);
    }

    function test_ReserveRemainsCorrectWithMultipleUsersClaiming() public {
        uint256 rewardAmount = 700 * UNIT;
        uint256 stakeAmount = 100 * UNIT;

        rewardToken.approve(address(staking), rewardAmount);
        staking.fundRewards(rewardAmount);

        // Alice deposita.
        vm.startPrank(alice);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Bob deposita en el mismo instante.
        vm.startPrank(bob);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Ambos acumulan recompensas durante un día.
        vm.warp(block.timestamp + 1 days);
        uint256 alicePending = staking.earned(alice);
        uint256 bobPending = staking.earned(bob);
        uint256 reserveBefore = staking.reservedRewards();
        assertGt(alicePending, 0);
        assertGt(bobPending, 0);

        // Alice reclama sus recompensas.
        vm.prank(alice);
        staking.getReward();
        assertEq(staking.reservedRewards(), reserveBefore - alicePending);

        // Bob todavía debe conservar sus recompensas pendientes.
        assertApproxEqAbs(staking.earned(bob), bobPending, 10 ** 12);

        // Bob reclama sus recompensas.
        vm.prank(bob);
        staking.getReward();
        assertEq(staking.reservedRewards(), reserveBefore - alicePending - bobPending);

        // La reserva debe seguir respaldada por el saldo del contrato.
        assertGe(rewardToken.balanceOf(address(staking)), staking.reservedRewards());
        assertEq(staking.earned(alice), 0);
        assertEq(staking.earned(bob), 0);
    }

    // =============================================================
    // 09. REWARD ACCOUNTING
    // =============================================================

    /* --- Successful operations --- */

    function test_AdditionalStakePreservesPreviousRewards() public {
        uint256 rewardAmount = 700 * UNIT;
        uint256 stakeAmount = 100 * UNIT;

        rewardToken.approve(address(staking), rewardAmount);
        staking.fundRewards(rewardAmount);

        // Alice necesita 100 tokens adicionales para depositar 100 + 100.
        token.transfer(alice, 100 * UNIT);
        vm.startPrank(alice);
        token.approve(address(staking), 2 * stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Alice mantiene 100 tokens durante un día.
        vm.warp(block.timestamp + 1 days);
        uint256 rewardsBeforeAdditionalStake = staking.earned(alice);

        // Alice deposita otros 100 tokens.
        vm.prank(alice);
        staking.stake(stakeAmount);

        // Las recompensas previas deben conservarse.
        assertEq(staking.rewards(alice), rewardsBeforeAdditionalStake);
        assertEq(staking.stakedBalance(alice), 2 * stakeAmount);

        // A partir de aquí, Alice acumulará con 200 tokens.
        vm.warp(block.timestamp + 1 days);
        assertGt(staking.earned(alice), rewardsBeforeAdditionalStake);
    }

    function test_PartialWithdrawPreservesPreviousRewards() public {
        uint256 rewardAmount = 700 * UNIT;
        uint256 stakeAmount = 100 * UNIT;
        uint256 withdrawAmount = 40 * UNIT;

        rewardToken.approve(address(staking), rewardAmount);
        staking.fundRewards(rewardAmount);
        vm.startPrank(alice);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Alice mantiene 100 tokens durante un día.
        vm.warp(block.timestamp + 1 days);
        uint256 rewardsBeforeWithdraw = staking.earned(alice);

        // Alice retira 40 tokens.
        vm.prank(alice);
        staking.withdraw(withdrawAmount);

        // Las recompensas anteriores deben quedar contabilizadas.
        assertEq(staking.rewards(alice), rewardsBeforeWithdraw);

        // Su stake pasa a ser de 60 tokens.
        assertEq(staking.stakedBalance(alice), stakeAmount - withdrawAmount);

        // Transcurre otro día con 60 tokens depositados.
        vm.warp(block.timestamp + 1 days);
        assertGt(staking.earned(alice), rewardsBeforeWithdraw);
    }

    function test_UnusedRewardsReleasedWhenFundingNextPeriod() public {
        uint256 firstAmount = 700 * UNIT;
        uint256 secondAmount = 200 * UNIT;

        // Financiar el primer periodo.
        rewardToken.approve(address(staking), firstAmount);
        staking.fundRewards(firstAmount);
        uint256 firstScheduled = staking.rewardRate() * staking.rewardsDuration();

        // Dejar terminar el periodo sin usuarios haciendo staking.
        vm.warp(staking.periodFinish());

        // Financiar el siguiente periodo.
        rewardToken.approve(address(staking), secondAmount);
        staking.fundRewards(secondAmount);
        uint256 secondScheduled = staking.rewardRate() * staking.rewardsDuration();

        // No se generaron recompensas durante el primer periodo.
        assertEq(staking.periodRewardsGenerated(), 0);

        // La reserva debe corresponder al nuevo periodo.
        assertEq(staking.reservedRewards(), secondScheduled);

        // Los fondos cubren el presupuesto reservado.
        assertGe(rewardToken.balanceOf(address(staking)), staking.reservedRewards());

        // Comprobación adicional: el primer presupuesto era mayor.
        assertGt(firstScheduled, secondScheduled);
    }

    function test_UnclaimedRewardsRemainReservedAcrossPeriods() public {
        uint256 firstAmount = 700 * UNIT;
        uint256 secondAmount = 200 * UNIT;
        uint256 stakeAmount = 100 * UNIT;

        // Financiar el primer periodo.
        rewardToken.approve(address(staking), firstAmount);
        staking.fundRewards(firstAmount);

        // Alice deposita.
        vm.startPrank(alice);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Alice acumula recompensas durante todo el periodo.
        vm.warp(staking.periodFinish());
        uint256 pendingBeforeFunding = staking.earned(alice);
        assertGt(pendingBeforeFunding, 0);

        // La reserva debe cubrir las recompensas pendientes.
        assertGe(staking.reservedRewards(), pendingBeforeFunding);

        // Comienza el segundo periodo.
        rewardToken.approve(address(staking), secondAmount);
        staking.fundRewards(secondAmount);

        // Alice conserva las recompensas del primer periodo.
        assertApproxEqAbs(staking.earned(alice), pendingBeforeFunding, 10 ** 12);
        assertGe(rewardToken.balanceOf(address(staking)), staking.reservedRewards());

        // Alice reclama lo pendiente del primer periodo.
        uint256 balanceBeforeClaim = rewardToken.balanceOf(alice);
        vm.prank(alice);
        staking.getReward();

        assertEq(rewardToken.balanceOf(alice), balanceBeforeClaim + pendingBeforeFunding);
        assertEq(staking.earned(alice), 0);

        // Los fondos reservados para el segundo periodo siguen disponibles.
        assertGe(rewardToken.balanceOf(address(staking)), staking.reservedRewards());
    }

    function test_WithdrawAndRestakePreservesRewardAccounting() public {
        uint256 rewardAmount = 700 * UNIT;
        uint256 stakeAmount = 100 * UNIT;

        rewardToken.approve(address(staking), rewardAmount);
        staking.fundRewards(rewardAmount);

        // Alice deposita.
        vm.startPrank(alice);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Alice acumula recompensas durante un día.
        vm.warp(block.timestamp + 1 days);
        uint256 rewardsBeforeWithdraw = staking.earned(alice);
        assertGt(rewardsBeforeWithdraw, 0);

        // Alice retira todos sus tokens.
        vm.prank(alice);
        staking.withdraw(stakeAmount);

        // Sus recompensas anteriores deben conservarse.
        assertEq(staking.earned(alice), rewardsBeforeWithdraw);
        assertEq(staking.stakedBalance(alice), 0);

        // Transcurre un día sin que Alice participe.
        vm.warp(block.timestamp + 1 days);

        // Vuelve a autorizar y depositar los mismos tokens.
        vm.startPrank(alice);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // No debe recibir recompensas por el día que estuvo fuera.
        assertEq(staking.earned(alice), rewardsBeforeWithdraw);

        // Reclama las recompensas que había acumulado antes de salir.
        vm.prank(alice);
        staking.getReward();
        assertEq(staking.earned(alice), 0);
        assertEq(staking.stakedBalance(alice), stakeAmount);

        // La reserva debe seguir respaldada.
        assertGe(rewardToken.balanceOf(address(staking)), staking.reservedRewards());
    }

    function test_ClaimsWithdrawalsAndNewPeriodPreserveAccounting() public {
        uint256 firstAmount = 700 * UNIT;
        uint256 secondAmount = 200 * UNIT;
        uint256 stakeAmount = 100 * UNIT;

        // Financiar el primer periodo.
        rewardToken.approve(address(staking), firstAmount);
        staking.fundRewards(firstAmount);

        // Alice y Bob depositan la misma cantidad.
        vm.startPrank(alice);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Transcurre un día.
        vm.warp(block.timestamp + 1 days);
        uint256 aliceFirstClaim = staking.earned(alice);
        uint256 bobPendingBeforeWithdraw = staking.earned(bob);

        assertGt(aliceFirstClaim, 0);
        assertGt(bobPendingBeforeWithdraw, 0);

        // Alice reclama sus recompensas.
        vm.prank(alice);
        staking.getReward();
        assertEq(staking.earned(alice), 0);

        // Bob retira todos sus tokens.
        vm.prank(bob);
        staking.withdraw(stakeAmount);
        assertEq(staking.stakedBalance(bob), 0);

        // Bob conserva las recompensas ganadas antes de retirar.
        assertApproxEqAbs(staking.earned(bob), bobPendingBeforeWithdraw, 10 ** 12);

        // Termina el primer periodo.
        vm.warp(staking.periodFinish());

        // Financiar el segundo periodo.
        rewardToken.approve(address(staking), secondAmount);
        staking.fundRewards(secondAmount);

        // Bob conserva sus recompensas pendientes.
        assertApproxEqAbs(staking.earned(bob), bobPendingBeforeWithdraw, 10 ** 12);

        // Alice conserva las recompensas generadas tras su primera reclamación.
        uint256 aliceRemainingRewards = staking.earned(alice);
        assertGt(aliceRemainingRewards, 0);

        // La reserva cubre las obligaciones de ambos usuarios.
        assertGe(staking.reservedRewards(), staking.earned(alice) + staking.earned(bob));

        // Bob reclama sus recompensas pendientes.
        vm.prank(bob);
        staking.getReward();

        assertEq(staking.earned(bob), 0);

        // Alice reclama las recompensas pendientes del primer periodo.
        vm.prank(alice);

        staking.getReward();
        assertEq(staking.earned(alice), 0);

        // Los fondos del segundo periodo siguen reservados.
        uint256 expectedNewPeriodReserve = staking.rewardRate() * staking.rewardsDuration();

        assertEq(staking.reservedRewards(), expectedNewPeriodReserve);
        assertGe(rewardToken.balanceOf(address(staking)), staking.reservedRewards());
    }
}
