// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {MyToken} from "../src/MyToken.sol";
import {Staking} from "../src/Staking.sol";

/// @title DeployStaking
/// @notice Deploys the staking demo, its ERC-20 tokens, and initial positions on a local chain.
contract DeployStaking is Script {
    uint256 internal constant TOKEN_SUPPLY = 1_000;
    uint256 internal constant DEMO_STAKE_AMOUNT = 100 ether;
    uint256 internal constant REWARD_FUNDING = 700 ether;

    error TokenApprovalFailed();

    function run() external returns (MyToken stakingToken, MyToken rewardsToken, Staking staking) {
        vm.startBroadcast();

        stakingToken = new MyToken(TOKEN_SUPPLY);
        rewardsToken = new MyToken(TOKEN_SUPPLY);
        staking = new Staking(address(stakingToken), address(rewardsToken));

        if (!stakingToken.approve(address(staking), DEMO_STAKE_AMOUNT)) {
            revert TokenApprovalFailed();
        }
        staking.stake(DEMO_STAKE_AMOUNT);

        if (!rewardsToken.approve(address(staking), REWARD_FUNDING)) {
            revert TokenApprovalFailed();
        }
        staking.fundRewards(REWARD_FUNDING);

        vm.stopBroadcast();

        console2.log("Staking contract:", address(staking));
        console2.log("Staking token (MyToken):", address(stakingToken));
        console2.log("Reward token (MyToken):", address(rewardsToken));
        console2.log("Owner and demo staker:", staking.owner());
        console2.log("Initial stake:", DEMO_STAKE_AMOUNT);
        console2.log("Reward funding:", REWARD_FUNDING);
    }
}
