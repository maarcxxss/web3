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

    address private marta = makeAddr("marta");
    address private marcos = makeAddr("marcos");

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

        token.transfer(marta, 100 * UNIT);
        token.transfer(marcos, 100 * UNIT);
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
        assertEq(staking.stakedBalance(marta), 0);
        assertEq(staking.stakedBalance(marcos), 0);
    }

    // =============================================================
    // 02. CONSTRUCTOR
    // =============================================================

    function test_RevertDeployWithZeroTokenAddress() public {
        vm.expectRevert(Staking.InvalidStakingTokenAddress.selector);
        new Staking(address(0), address(rewardToken));
    }

    function test_RevertDeployWithNonContractStakingToken() public {
        vm.expectRevert(Staking.StakingTokenHasNoCode.selector);
        new Staking(address(1), address(rewardToken));
    }

    function test_RevertDeployWithZeroRewardsTokenAddress() public {
        vm.expectRevert(Staking.InvalidRewardsTokenAddress.selector);
        new Staking(address(token), address(0));
    }

    function test_RevertDeployWithNonContractRewardsToken() public {
        vm.expectRevert(Staking.RewardsTokenHasNoCode.selector);
        new Staking(address(token), address(1));
    }

    // =============================================================
    // 03. STAKING
    // =============================================================

    /* --- Successful operations --- */

    function test_Stake() public {
        vm.startPrank(marta);
        token.approve(address(staking), 50 * UNIT);
        staking.stake(50 * UNIT);
        vm.stopPrank();

        assertEq(token.balanceOf(marta), 50 * UNIT);
        assertEq(token.balanceOf(address(staking)), 50 * UNIT);
        assertEq(staking.stakedBalance(marta), 50 * UNIT);
    }

    function test_MultipleUsers() public {
        // Marta hace stake de 50
        vm.startPrank(marta);
        token.approve(address(staking), 50 * UNIT);
        staking.stake(50 * UNIT);
        vm.stopPrank();

        // Marcos hace stake de 30
        vm.startPrank(marcos);
        token.approve(address(staking), 30 * UNIT);
        staking.stake(30 * UNIT);
        vm.stopPrank();

        // Comprobamos los balances individuales
        assertEq(staking.stakedBalance(marta), 50 * UNIT);
        assertEq(staking.stakedBalance(marcos), 30 * UNIT);

        // El contrato posee 80 MTO en total
        assertEq(token.balanceOf(address(staking)), 80 * UNIT);
    }

    /* --- Reverts --- */

    function test_RevertStakeZero() public {
        vm.expectRevert(Staking.AmountMustBeGreaterThanZero.selector);

        vm.prank(marta);
        staking.stake(0);
    }

    function test_RevertStakeWithoutApproval() public {
        vm.expectRevert();

        vm.prank(marta);
        staking.stake(50 * UNIT);
    }

    function test_RevertStakeMoreThanWalletBalance() public {
        vm.startPrank(marta);
        token.approve(address(staking), 101 * UNIT);
        vm.expectRevert();
        staking.stake(101 * UNIT);
        vm.stopPrank();
    }

    function test_RevertStakeWithFeeToken() public {
        FeeToken feeToken = new FeeToken(1000 * UNIT);
        Staking feeStaking = new Staking(address(feeToken), address(rewardToken));
        address martaFee = makeAddr("martaFee");
        feeToken.transfer(martaFee, 200 * UNIT);
        vm.startPrank(martaFee);
        feeToken.approve(address(feeStaking), 100 * UNIT);
        vm.expectRevert(abi.encodeWithSelector(Staking.UnexpectedAmountReceived.selector, 100 * UNIT, 98 * UNIT));
        feeStaking.stake(100 * UNIT);
        vm.stopPrank();

        assertEq(feeStaking.stakedBalance(martaFee), 0);
        assertEq(feeStaking.totalStaked(), 0);
        assertEq(feeToken.balanceOf(address(feeStaking)), 0);
    }

    function test_RevertStakeWhenTokenTransferFromReturnsFalse() public {
        CoverageERC20 coverageToken = new CoverageERC20(100 * UNIT);
        Staking coverageStaking = new Staking(address(coverageToken), address(rewardToken));
        coverageToken.transfer(marta, 10 * UNIT);
        coverageToken.setTransferFromReturns(false);

        vm.startPrank(marta);
        coverageToken.approve(address(coverageStaking), UNIT);
        vm.expectRevert(Staking.StakingTokenTransferFailed.selector);
        coverageStaking.stake(UNIT);
        vm.stopPrank();

        assertEq(coverageStaking.stakedBalance(marta), 0);
        assertEq(coverageStaking.totalStaked(), 0);
    }

    function test_RevertOnReentrantStake() public {
        CoverageERC20 coverageToken = new CoverageERC20(100 * UNIT);
        Staking coverageStaking = new Staking(address(coverageToken), address(rewardToken));
        coverageToken.transfer(marta, 10 * UNIT);
        coverageToken.setCallback(address(coverageStaking), abi.encodeCall(Staking.stake, (UNIT)), false);

        vm.startPrank(marta);
        coverageToken.approve(address(coverageStaking), UNIT);
        coverageStaking.stake(UNIT);
        vm.stopPrank();

        bytes memory callbackRevert = coverageToken.callbackReturndata();
        bytes4 callbackError;
        assembly ("memory-safe") {
            callbackError := mload(add(callbackRevert, 32))
        }
        assertFalse(coverageToken.callbackSucceeded());
        assertEq(callbackError, Staking.ReentrantCall.selector);
        assertEq(coverageStaking.stakedBalance(marta), UNIT);
        assertEq(coverageStaking.totalStaked(), UNIT);
    }

    // =============================================================
    // 04. WITHDRAWALS
    // =============================================================

    /* --- Successful operations --- */

    function test_Withdraw() public {
        vm.startPrank(marta);
        token.approve(address(staking), 50 * UNIT);
        staking.stake(50 * UNIT);
        staking.withdraw(20 * UNIT);
        vm.stopPrank();

        assertEq(token.balanceOf(marta), 70 * UNIT);
        assertEq(token.balanceOf(address(staking)), 30 * UNIT);
        assertEq(staking.stakedBalance(marta), 30 * UNIT);
    }

    function test_WithdrawDoesNotAffectOtherUsers() public {
        // Marta hace stake de 50 tokens
        vm.startPrank(marta);
        token.approve(address(staking), 50 * UNIT);
        staking.stake(50 * UNIT);
        vm.stopPrank();

        // Marcos hace stake de 30 tokens
        vm.startPrank(marcos);
        token.approve(address(staking), 30 * UNIT);
        staking.stake(30 * UNIT);
        vm.stopPrank();

        // Marta retira 20 tokens
        vm.startPrank(marta);
        staking.withdraw(20 * UNIT);
        vm.stopPrank();

        // Comprobamos los balances internos
        assertEq(staking.stakedBalance(marta), 30 * UNIT);
        assertEq(staking.stakedBalance(marcos), 30 * UNIT);

        // Comprobamos los tokens reales que tiene Staking
        assertEq(token.balanceOf(address(staking)), 60 * UNIT);

        // Comprobacion para contabilizar que el total staked es a la suma de los usuarios que tienen en el contrato de staking (30+30)
        assertEq(staking.totalStaked(), 60 * UNIT);

        // Comprobacion para comprobar que el total staked es igual al balance de tokens en el ERC-20
        assertEq(staking.totalStaked(), token.balanceOf(address(staking)));
    }

    function test_WithdrawEntireStake() public {
        uint256 amount = 50 * UNIT;

        vm.startPrank(marta);
        token.approve(address(staking), amount);
        staking.stake(amount);
        staking.withdraw(amount);
        vm.stopPrank();

        assertEq(staking.stakedBalance(marta), 0);
        assertEq(staking.totalStaked(), 0);
        assertEq(token.balanceOf(address(staking)), 0);
        assertEq(token.balanceOf(marta), 100 * UNIT);
    }

    /* --- Reverts --- */

    function test_RevertWithdrawZero() public {
        vm.expectRevert(Staking.AmountMustBeGreaterThanZero.selector);

        vm.prank(marta);
        staking.withdraw(0);
    }

    function test_RevertWithdrawMoreThanStaked() public {
        vm.startPrank(marta);
        token.approve(address(staking), 50 * UNIT);
        staking.stake(50 * UNIT);
        vm.expectRevert(abi.encodeWithSelector(Staking.InsufficientStakedBalance.selector, 50 * UNIT, 60 * UNIT));
        staking.withdraw(60 * UNIT);
        vm.stopPrank();
    }

    function test_RevertWithdrawWithoutStake() public {
        vm.expectRevert(abi.encodeWithSelector(Staking.InsufficientStakedBalance.selector, 0, 1));

        vm.prank(marta);
        staking.withdraw(1);
    }

    function test_RevertWithdrawWhenTokenTransferReturnsFalse() public {
        CoverageERC20 coverageToken = new CoverageERC20(100 * UNIT);
        Staking coverageStaking = new Staking(address(coverageToken), address(rewardToken));
        coverageToken.transfer(marta, 10 * UNIT);

        vm.startPrank(marta);
        coverageToken.approve(address(coverageStaking), 5 * UNIT);
        coverageStaking.stake(5 * UNIT);
        vm.stopPrank();

        coverageToken.setTransferReturns(false);
        vm.expectRevert(Staking.StakingTokenTransferFailed.selector);
        vm.prank(marta);
        coverageStaking.withdraw(2 * UNIT);

        // El revert revierte también los cambios de estado previos a transfer.
        assertEq(coverageStaking.stakedBalance(marta), 5 * UNIT);
        assertEq(coverageStaking.totalStaked(), 5 * UNIT);
    }

    // =============================================================
    // 05. EVENTS
    // =============================================================

    /* --- Events --- */

    function test_StakeEmitsEvent() public {
        vm.startPrank(marta);
        token.approve(address(staking), 50 * UNIT);

        vm.expectEmit(true, false, false, true);
        emit IStaking.Staked(marta, 50 * UNIT);

        staking.stake(50 * UNIT);
        vm.stopPrank();
    }

    function test_WithdrawEmitsEvent() public {
        vm.startPrank(marta);
        token.approve(address(staking), 50 * UNIT);
        staking.stake(50 * UNIT);

        vm.expectEmit(true, false, false, true);
        emit IStaking.Withdrawn(marta, 20 * UNIT);

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

        vm.expectRevert(Staking.RewardsTokenTransferFailed.selector);
        coverageStaking.fundRewards(700 * UNIT);
    }

    function test_RevertFundRewardsWhenRewardRateIsZero() public {
        rewardToken.approve(address(staking), 1);

        vm.expectRevert(abi.encodeWithSelector(Staking.RewardRateIsZero.selector, 1, staking.rewardsDuration()));
        staking.fundRewards(1);
    }

    function test_RevertFundRewardsWhenReserveIsInsufficient() public {
        uint256 firstFunding = 700 * UNIT;
        uint256 nextFunding = 200 * UNIT;
        uint256 stakeAmount = 100 * UNIT;

        rewardToken.approve(address(staking), firstFunding);
        staking.fundRewards(firstFunding);

        vm.startPrank(marta);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Marta permanece en staking durante todo el periodo y actualiza la contabilidad al retirarse.
        vm.warp(staking.periodFinish());
        vm.prank(marta);
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
            abi.encodeWithSelector(Staking.InsufficientRewardReserve.selector, nextFunding, requiredBalance)
        );
        staking.fundRewards(nextFunding);
    }

    /* --- Reverts --- */

    function test_RevertFundRewardsDuringActivePeriod() public {
        uint256 rewardAmount = 700 * UNIT;
        rewardToken.approve(address(staking), rewardAmount);
        staking.fundRewards(rewardAmount);

        vm.expectRevert(abi.encodeWithSelector(Staking.RewardPeriodActive.selector, staking.periodFinish()));
        staking.fundRewards(1 * UNIT);
    }

    function test_RevertFundRewardsZero() public {
        vm.expectRevert(Staking.AmountMustBeGreaterThanZero.selector);
        staking.fundRewards(0);
    }

    function test_RevertFundRewardsUnauthorized() public {
        vm.expectRevert(Staking.NotOwner.selector);

        vm.prank(marta);
        staking.fundRewards(UNIT);
    }

    function test_RevertFundRewardsWithFeeToken() public {
        FeeToken feeRewardToken = new FeeToken(1000 * UNIT);
        Staking feeRewardStaking = new Staking(address(token), address(feeRewardToken));
        uint256 amount = 100 * UNIT;
        feeRewardToken.approve(address(feeRewardStaking), amount);

        vm.expectRevert(
            abi.encodeWithSelector(Staking.UnexpectedAmountReceived.selector, amount, amount - (amount * 2 / 100))
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
        uint256 martaStake = 100 * UNIT;
        uint256 marcosStake = 300 * UNIT;

        // Financiamos el periodo de recompensas.
        rewardToken.approve(address(staking), rewardAmount);
        staking.fundRewards(rewardAmount);

        // Marcos necesita 200 tokens adicionales para depositar 300.
        token.transfer(marcos, 200 * UNIT);

        // Marta deposita 100 tokens.
        vm.startPrank(marta);
        token.approve(address(staking), martaStake);
        staking.stake(martaStake);
        vm.stopPrank();

        // Marcos deposita 300 tokens.
        vm.startPrank(marcos);
        token.approve(address(staking), marcosStake);
        staking.stake(marcosStake);
        vm.stopPrank();

        // Avanzamos un día.
        uint256 elapsed = 1 days;
        vm.warp(block.timestamp + elapsed);

        // Calculamos la distribución esperada.
        uint256 totalRewards = staking.rewardRate() * elapsed;
        uint256 expectedMarta = totalRewards / 4;
        uint256 expectedMarcos = totalRewards * 3 / 4;

        assertApproxEqAbs(staking.earned(marta), expectedMarta, 1e12);
        assertApproxEqAbs(staking.earned(marcos), expectedMarcos, 1e12);
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

        // Día 0: Marta deposita 100 tokens.
        vm.startPrank(marta);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Día 1: transcurre un día.
        vm.warp(block.timestamp + 1 days);

        // Marcos entra cuando Marta ya lleva un día participando.
        vm.startPrank(marcos);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Día 2: ambos han participado durante tiempos distintos.
        vm.warp(block.timestamp + 1 days);
        uint256 martaRewards = staking.earned(marta);
        uint256 marcosRewards = staking.earned(marcos);

        // Marta debe tener aproximadamente 150 tokens.
        assertApproxEqAbs(martaRewards, 150 * UNIT, 10 ** 12);

        // Marcos debe tener aproximadamente 50 tokens.
        assertApproxEqAbs(marcosRewards, 50 * UNIT, 10 ** 12);

        // Marta debe haber ganado aproximadamente el triple.
        assertApproxEqAbs(martaRewards, marcosRewards * 3, 10 ** 12);
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

        // Marta deposita sus tokens.
        vm.startPrank(marta);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Dejamos que se acumulen recompensas.
        vm.warp(block.timestamp + 1 days);
        uint256 expectedReward = staking.earned(marta);
        uint256 balanceBefore = rewardToken.balanceOf(marta);
        uint256 reserveBefore = staking.reservedRewards();

        vm.expectEmit(true, false, false, true);
        emit IStaking.RewardPaid(marta, expectedReward);

        vm.prank(marta);
        staking.getReward();

        assertEq(rewardToken.balanceOf(marta), balanceBefore + expectedReward);
        assertEq(staking.reservedRewards(), reserveBefore - expectedReward);
        assertEq(staking.rewards(marta), 0);
        assertEq(staking.earned(marta), 0);
        assertEq(staking.stakedBalance(marta), stakeAmount);
        assertEq(token.balanceOf(address(staking)), stakeAmount);
    }

    function test_RevertGetRewardWhenTransferReturnsFalse() public {
        CoverageERC20 coverageRewardToken = new CoverageERC20(1000 * UNIT);
        Staking coverageStaking = new Staking(address(token), address(coverageRewardToken));
        uint256 rewardFunding = 700 * UNIT;
        uint256 stakeAmount = 100 * UNIT;

        coverageRewardToken.approve(address(coverageStaking), rewardFunding);
        coverageStaking.fundRewards(rewardFunding);

        vm.startPrank(marta);
        token.approve(address(coverageStaking), stakeAmount);
        coverageStaking.stake(stakeAmount);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        uint256 reserveBeforeClaim = coverageStaking.reservedRewards();
        assertGt(coverageStaking.earned(marta), 0);

        coverageRewardToken.setTransferReturns(false);
        vm.expectRevert(Staking.RewardsTokenTransferFailed.selector);
        vm.prank(marta);
        coverageStaking.getReward();

        // La operación revertida no borra la deuda ni reduce la reserva.
        assertGt(coverageStaking.earned(marta), 0);
        assertEq(coverageStaking.reservedRewards(), reserveBeforeClaim);
    }

    function test_ClaimedRewardsAreNotReservedAgain() public {
        uint256 firstAmount = 700 * UNIT;
        uint256 stakeAmount = 100 * UNIT;

        // Financiar el primer periodo.
        rewardToken.approve(address(staking), firstAmount);
        staking.fundRewards(firstAmount);

        // Marta hace staking.
        vm.startPrank(marta);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Dejar que se acumulen recompensas.
        vm.warp(block.timestamp + 1 days);
        uint256 pendingRewards = staking.earned(marta);
        assertGt(pendingRewards, 0);
        uint256 reserveBeforeClaim = staking.reservedRewards();

        // Marta reclama las recompensas.
        vm.prank(marta);
        staking.getReward();

        // La reserva disminuye exactamente lo reclamado.
        assertEq(staking.reservedRewards(), reserveBeforeClaim - pendingRewards);
        uint256 balanceAfterFirstClaim = rewardToken.balanceOf(marta);
        assertEq(balanceAfterFirstClaim, pendingRewards);

        // Termina el primer periodo.
        vm.warp(staking.periodFinish());

        // Financiar el segundo periodo.
        uint256 secondAmount = 200 * UNIT;
        rewardToken.approve(address(staking), secondAmount);
        staking.fundRewards(secondAmount);
        uint256 pendingAfterFirstClaim = staking.earned(marta);
        assertGt(pendingAfterFirstClaim, 0);
        uint256 balanceBeforeSecondClaim = rewardToken.balanceOf(marta);
        vm.prank(marta);
        staking.getReward();
        assertEq(rewardToken.balanceOf(marta), balanceBeforeSecondClaim + pendingAfterFirstClaim);
        assertEq(staking.earned(marta), 0);

        // Una tercera reclamación no debe pagar nada adicional.
        uint256 balanceAfterSecondClaim = rewardToken.balanceOf(marta);
        vm.prank(marta);
        staking.getReward();

        assertEq(rewardToken.balanceOf(marta), balanceAfterSecondClaim);
    }

    function test_ReserveRemainsCorrectWithMultipleUsersClaiming() public {
        uint256 rewardAmount = 700 * UNIT;
        uint256 stakeAmount = 100 * UNIT;

        rewardToken.approve(address(staking), rewardAmount);
        staking.fundRewards(rewardAmount);

        // Marta deposita.
        vm.startPrank(marta);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Marcos deposita en el mismo instante.
        vm.startPrank(marcos);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Ambos acumulan recompensas durante un día.
        vm.warp(block.timestamp + 1 days);
        uint256 martaPending = staking.earned(marta);
        uint256 marcosPending = staking.earned(marcos);
        uint256 reserveBefore = staking.reservedRewards();
        assertGt(martaPending, 0);
        assertGt(marcosPending, 0);

        // Marta reclama sus recompensas.
        vm.prank(marta);
        staking.getReward();
        assertEq(staking.reservedRewards(), reserveBefore - martaPending);

        // Marcos todavía debe conservar sus recompensas pendientes.
        assertApproxEqAbs(staking.earned(marcos), marcosPending, 10 ** 12);

        // Marcos reclama sus recompensas.
        vm.prank(marcos);
        staking.getReward();
        assertEq(staking.reservedRewards(), reserveBefore - martaPending - marcosPending);

        // La reserva debe seguir respaldada por el saldo del contrato.
        assertGe(rewardToken.balanceOf(address(staking)), staking.reservedRewards());
        assertEq(staking.earned(marta), 0);
        assertEq(staking.earned(marcos), 0);
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

        // Marta necesita 100 tokens adicionales para depositar 100 + 100.
        token.transfer(marta, 100 * UNIT);
        vm.startPrank(marta);
        token.approve(address(staking), 2 * stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Marta mantiene 100 tokens durante un día.
        vm.warp(block.timestamp + 1 days);
        uint256 rewardsBeforeAdditionalStake = staking.earned(marta);

        // Marta deposita otros 100 tokens.
        vm.prank(marta);
        staking.stake(stakeAmount);

        // Las recompensas previas deben conservarse.
        assertEq(staking.rewards(marta), rewardsBeforeAdditionalStake);
        assertEq(staking.stakedBalance(marta), 2 * stakeAmount);

        // A partir de aquí, Marta acumulará con 200 tokens.
        vm.warp(block.timestamp + 1 days);
        assertGt(staking.earned(marta), rewardsBeforeAdditionalStake);
    }

    function test_PartialWithdrawPreservesPreviousRewards() public {
        uint256 rewardAmount = 700 * UNIT;
        uint256 stakeAmount = 100 * UNIT;
        uint256 withdrawAmount = 40 * UNIT;

        rewardToken.approve(address(staking), rewardAmount);
        staking.fundRewards(rewardAmount);
        vm.startPrank(marta);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Marta mantiene 100 tokens durante un día.
        vm.warp(block.timestamp + 1 days);
        uint256 rewardsBeforeWithdraw = staking.earned(marta);

        // Marta retira 40 tokens.
        vm.prank(marta);
        staking.withdraw(withdrawAmount);

        // Las recompensas anteriores deben quedar contabilizadas.
        assertEq(staking.rewards(marta), rewardsBeforeWithdraw);

        // Su stake pasa a ser de 60 tokens.
        assertEq(staking.stakedBalance(marta), stakeAmount - withdrawAmount);

        // Transcurre otro día con 60 tokens depositados.
        vm.warp(block.timestamp + 1 days);
        assertGt(staking.earned(marta), rewardsBeforeWithdraw);
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

        // Marta deposita.
        vm.startPrank(marta);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Marta acumula recompensas durante todo el periodo.
        vm.warp(staking.periodFinish());
        uint256 pendingBeforeFunding = staking.earned(marta);
        assertGt(pendingBeforeFunding, 0);

        // La reserva debe cubrir las recompensas pendientes.
        assertGe(staking.reservedRewards(), pendingBeforeFunding);

        // Comienza el segundo periodo.
        rewardToken.approve(address(staking), secondAmount);
        staking.fundRewards(secondAmount);

        // Marta conserva las recompensas del primer periodo.
        assertApproxEqAbs(staking.earned(marta), pendingBeforeFunding, 10 ** 12);
        assertGe(rewardToken.balanceOf(address(staking)), staking.reservedRewards());

        // Marta reclama lo pendiente del primer periodo.
        uint256 balanceBeforeClaim = rewardToken.balanceOf(marta);
        vm.prank(marta);
        staking.getReward();

        assertEq(rewardToken.balanceOf(marta), balanceBeforeClaim + pendingBeforeFunding);
        assertEq(staking.earned(marta), 0);

        // Los fondos reservados para el segundo periodo siguen disponibles.
        assertGe(rewardToken.balanceOf(address(staking)), staking.reservedRewards());
    }

    function test_WithdrawAndRestakePreservesRewardAccounting() public {
        uint256 rewardAmount = 700 * UNIT;
        uint256 stakeAmount = 100 * UNIT;

        rewardToken.approve(address(staking), rewardAmount);
        staking.fundRewards(rewardAmount);

        // Marta deposita.
        vm.startPrank(marta);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Marta acumula recompensas durante un día.
        vm.warp(block.timestamp + 1 days);
        uint256 rewardsBeforeWithdraw = staking.earned(marta);
        assertGt(rewardsBeforeWithdraw, 0);

        // Marta retira todos sus tokens.
        vm.prank(marta);
        staking.withdraw(stakeAmount);

        // Sus recompensas anteriores deben conservarse.
        assertEq(staking.earned(marta), rewardsBeforeWithdraw);
        assertEq(staking.stakedBalance(marta), 0);

        // Transcurre un día sin que Marta participe.
        vm.warp(block.timestamp + 1 days);

        // Vuelve a autorizar y depositar los mismos tokens.
        vm.startPrank(marta);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // No debe recibir recompensas por el día que estuvo fuera.
        assertEq(staking.earned(marta), rewardsBeforeWithdraw);

        // Reclama las recompensas que había acumulado antes de salir.
        vm.prank(marta);
        staking.getReward();
        assertEq(staking.earned(marta), 0);
        assertEq(staking.stakedBalance(marta), stakeAmount);

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

        // Marta y Marcos depositan la misma cantidad.
        vm.startPrank(marta);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        vm.startPrank(marcos);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        vm.stopPrank();

        // Transcurre un día.
        vm.warp(block.timestamp + 1 days);
        uint256 martaFirstClaim = staking.earned(marta);
        uint256 marcosPendingBeforeWithdraw = staking.earned(marcos);

        assertGt(martaFirstClaim, 0);
        assertGt(marcosPendingBeforeWithdraw, 0);

        // Marta reclama sus recompensas.
        vm.prank(marta);
        staking.getReward();
        assertEq(staking.earned(marta), 0);

        // Marcos retira todos sus tokens.
        vm.prank(marcos);
        staking.withdraw(stakeAmount);
        assertEq(staking.stakedBalance(marcos), 0);

        // Marcos conserva las recompensas ganadas antes de retirar.
        assertApproxEqAbs(staking.earned(marcos), marcosPendingBeforeWithdraw, 10 ** 12);

        // Termina el primer periodo.
        vm.warp(staking.periodFinish());

        // Financiar el segundo periodo.
        rewardToken.approve(address(staking), secondAmount);
        staking.fundRewards(secondAmount);

        // Marcos conserva sus recompensas pendientes.
        assertApproxEqAbs(staking.earned(marcos), marcosPendingBeforeWithdraw, 10 ** 12);

        // Marta conserva las recompensas generadas tras su primera reclamación.
        uint256 martaRemainingRewards = staking.earned(marta);
        assertGt(martaRemainingRewards, 0);

        // La reserva cubre las obligaciones de ambos usuarios.
        assertGe(staking.reservedRewards(), staking.earned(marta) + staking.earned(marcos));

        // Marcos reclama sus recompensas pendientes.
        vm.prank(marcos);
        staking.getReward();

        assertEq(staking.earned(marcos), 0);

        // Marta reclama las recompensas pendientes del primer periodo.
        vm.prank(marta);

        staking.getReward();
        assertEq(staking.earned(marta), 0);

        // Los fondos del segundo periodo siguen reservados.
        uint256 expectedNewPeriodReserve = staking.rewardRate() * staking.rewardsDuration();

        assertEq(staking.reservedRewards(), expectedNewPeriodReserve);
        assertGe(rewardToken.balanceOf(address(staking)), staking.reservedRewards());
    }
}
