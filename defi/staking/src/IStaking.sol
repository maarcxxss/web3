// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "./IERC20.sol";

/// @title IStaking
/// @notice External API for the staking and reward-distribution contract.
interface IStaking {
    // =============================================================
    // EVENTS
    // =============================================================

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    // =============================================================
    // STATE QUERIES
    // =============================================================

    function owner() external view returns (address);
    function token() external view returns (IERC20);
    function rewardsToken() external view returns (IERC20);
    function totalStaked() external view returns (uint256);
    function stakedBalance(address user) external view returns (uint256);

    function rewardRate() external view returns (uint256);
    function lastUpdateTime() external view returns (uint256);
    function rewardPerTokenStored() external view returns (uint256);
    function userRewardPerTokenPaid(address user) external view returns (uint256);
    function rewards(address user) external view returns (uint256);
    function reservedRewards() external view returns (uint256);
    function periodRewardsGenerated() external view returns (uint256);
    function periodFinish() external view returns (uint256);
    function rewardsDuration() external view returns (uint256);

    function lastTimeRewardApplicable() external view returns (uint256);
    function rewardPerToken() external view returns (uint256);
    function earned(address user) external view returns (uint256);

    // =============================================================
    // USER AND OWNER ACTIONS
    // =============================================================

    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function fundRewards(uint256 amount) external;
    function getReward() external;
}
