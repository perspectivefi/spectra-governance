// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "./BaseTest.sol";
import {VelodromeTimeLibrary} from "../contracts/libraries/VelodromeTimeLibrary.sol";

contract BribeVotingRewardTest is BaseTest {
    event NotifyReward(address indexed from, address indexed reward, uint256 indexed epoch, uint256 amount);

    function _setUp() public override {
        // ve
        vm.startPrank(owner, owner);
        voter.setApprovalForAll(address(this), true);
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, block.timestamp + MAXTIME);
        vm.startPrank(address(owner2), owner2);
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, block.timestamp + MAXTIME);
        vm.stopPrank();
        vm.startPrank(address(owner3), owner3);
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, block.timestamp + MAXTIME);
        vm.stopPrank();
        skip(1);
    }

    function testCannotRestrictedFunctionsWithoutVoterRole() public {
        bytes memory revertData = abi.encodeWithSelector(
            IAccessManaged.AccessManagedUnauthorized.selector,
            address(this)
        );
        vm.expectRevert(revertData);
        feesVotingReward._deposit(0, owner);
        vm.expectRevert(revertData);
        feesVotingReward._withdraw(0, owner);
        vm.expectRevert(revertData);
        feesVotingReward.setDaoFee(0);

        vm.startPrank(address(voter));
        feesVotingReward._deposit(0, owner);
        feesVotingReward._withdraw(0, owner);
        feesVotingReward.setDaoFee(0);
    }

    function testCannotGetRewardIfNotOwnerOrApprovedNorWithVoterRole() public {
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        vm.startPrank(address(owner));
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, owner));
        feesVotingReward.getReward(address(owner2), address(LR));
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, owner));
        feesVotingReward.getRewards(address(owner2), rewards);
    }

    function testGetRewardWithZeroTotalSupply() public {
        skip(1 weeks / 2);

        // create a bribe
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);

        // vote
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;
        voter.vote(address(owner), poolIds, weights);

        skipToNextEpoch(1);

        // check earned is correct
        uint256 earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1);

        // add bribe for epoch 2
        LR.approve(address(bribeVotingReward), TOKEN_1 * 2);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1 * 2);
        skip(1 hours);

        // remove supply by voting for other pool
        poolIds[0] = poolId2;
        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();

        assertEq(bribeVotingReward.totalSupply(), 0);

        skipToNextEpoch(1);

        // check can still claim bribe
        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1);
    }

    function testGetRewardWithMultipleStaggeredRewardsInOneEpoch() public {
        skip(1 weeks / 2);

        uint256 reward = TOKEN_1;
        uint256 reward2 = TOKEN_1 * 2;

        // create a bribe
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), reward);
        bribeVotingReward.notifyRewardAmount((address(LR)), reward);

        // vote
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;
        voter.vote(address(owner), poolIds, weights);

        skip(1 days);

        // create another bribe for the same pool in the same epoch
        LR.approve(address(bribeVotingReward), reward2);
        bribeVotingReward.notifyRewardAmount((address(LR)), reward2);

        skipToNextEpoch(1);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        uint256 pre = LR.balanceOf(address(owner));
        vm.stopPrank();
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));

        // expect both rewards
        uint256 totalReward = reward + reward2;
        assertEq(post - pre, totalReward);
    }

    function testCannotGetRewardMoreThanOncePerEpochWithSingleReward() public {
        skip(1 weeks / 2);

        // create a bribe
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);

        // vote
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;
        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();

        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);

        skipToNextEpoch(1);

        uint256 pre = LR.balanceOf(address(owner));
        uint256 earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1 / 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        vm.startPrank(address(voter));
        // claim first time
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));
        skip(1);
        // claim second time
        bribeVotingReward.getRewards(address(owner), rewards);
        vm.stopPrank();

        uint256 post_post = LR.balanceOf(address(owner));
        assertEq(post_post, post);
        assertEq(post_post - pre, TOKEN_1 / 2);
    }

    function testCannotGetRewardMoreThanOncePerEpochWithMultipleRewards() public {
        skip(1 weeks / 2);

        // create a bribe
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);

        // vote
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;
        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();

        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);

        skipToNextEpoch(1);

        uint256 pre = LR.balanceOf(address(owner));
        uint256 earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1 / 2);

        // rewards
        address[] memory rewards = new address[](2);
        rewards[0] = address(LR);
        rewards[1] = address(LR);

        vm.startPrank(address(voter));
        // claim first time
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));
        // claim second time
        bribeVotingReward.getRewards(address(owner), rewards);
        vm.stopPrank();

        uint256 post_post = LR.balanceOf(address(owner));
        assertEq(post_post, post);
        assertEq(post_post - pre, TOKEN_1 / 2);
    }

    function testGetRewardWithMultipleVotes() public {
        skip(1 weeks / 2);

        uint256 reward = TOKEN_1;
        uint256 reward2 = TOKEN_1 * 2;

        // create a bribe
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), reward);
        bribeVotingReward.notifyRewardAmount((address(LR)), reward);

        // vote
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        voter.vote(address(owner), poolIds, weights);

        skipToNextEpoch(1 hours + 1);

        // create another bribe for the same pool the following week
        LR.approve(address(bribeVotingReward), reward2);
        bribeVotingReward.notifyRewardAmount((address(LR)), reward2);

        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();

        skipToNextEpoch(1);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));

        uint256 totalReward = reward + reward2;
        assertEq(post - pre, totalReward);
    }

    function testGetRewardWithVotesForDifferentPoolsAcrossEpochs() public {
        skip(1 weeks / 2);

        uint256 reward = TOKEN_1;
        uint256 reward2 = TOKEN_1 * 2;

        // create a bribe for pool1 in epoch 0
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), reward);
        bribeVotingReward.notifyRewardAmount((address(LR)), reward);

        // vote
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);

        skipToNextEpoch(1 hours + 1);

        // create a bribe for pool2 in epoch 1
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward2), reward2);
        bribeVotingReward2.notifyRewardAmount((address(LR)), reward2);
        poolIds[0] = poolId2;

        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();

        skipToNextEpoch(1);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        // check rewards accrue correctly for pool1
        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));

        assertEq(post - pre, reward / 2);

        // check rewards accrue correctly for pool2
        pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward2.getRewards(address(owner), rewards);
        post = LR.balanceOf(address(owner));

        assertEq(post - pre, reward2);
    }

    function testGetRewardWithPassiveVote() public {
        skip(1 weeks / 2);

        // create a bribe in epoch 0
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);
        assertEq(LR.balanceOf(address(bribeVotingReward)), TOKEN_1);

        // vote
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;
        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();
        skip(1);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        uint256 earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, 0);

        skipToNextEpoch(1);

        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, 0);

        // create another bribe in epoch 1 but do not vote
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1 * 2);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1 * 2);
        assertEq(LR.balanceOf(address(bribeVotingReward)), TOKEN_1 * 2);
        vm.stopPrank();

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, 0);

        skipToNextEpoch(1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1 * 2);

        pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 * 2);
    }

    function testGetRewardWithPassiveVotes() public {
        skip(1 weeks / 2);

        // create a bribe
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount((address(LR)), TOKEN_1);

        // vote in epoch 0
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();
        skip(1);

        uint256 earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, 0);

        // epoch 1: five epochs pass, with an incrementing reward
        skipToNextEpoch(1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1);

        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1 * 2);
        bribeVotingReward.notifyRewardAmount((address(LR)), TOKEN_1 * 2);
        vm.stopPrank();
        skip(1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1);

        // epoch 2
        skipToNextEpoch(1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1 * 3);

        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1 * 3);
        bribeVotingReward.notifyRewardAmount((address(LR)), TOKEN_1 * 3);
        skip(1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1 * 3);

        // epoch 3
        skipToNextEpoch(1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1 * 6);

        LR.approve(address(bribeVotingReward), TOKEN_1 * 4);
        bribeVotingReward.notifyRewardAmount((address(LR)), TOKEN_1 * 4);
        skip(1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1 * 6);

        // epoch 4
        skipToNextEpoch(1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1 * 10);

        LR.approve(address(bribeVotingReward), TOKEN_1 * 5);
        bribeVotingReward.notifyRewardAmount((address(LR)), TOKEN_1 * 5);
        skip(1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1 * 10);

        // epoch 5
        skipToNextEpoch(1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1 * 15);

        LR.approve(address(bribeVotingReward), TOKEN_1 * 6);
        bribeVotingReward.notifyRewardAmount((address(LR)), TOKEN_1 * 6);
        vm.stopPrank();
        skip(1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1 * 15);

        skipToNextEpoch(1);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        // total rewards: 1 + 2 + 3 + 4 + 5 + 6
        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));

        assertEq(post - pre, TOKEN_1 * 21);
    }

    function testCannotGetRewardInSameWeekIfEpochYetToFlip() public {
        /// tests that rewards deposited that week cannot be claimed until next week
        skip(1 weeks / 2);

        // create bribe in epoch 0
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount((address(LR)), TOKEN_1);

        // vote in epoch 0
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        voter.vote(address(owner), poolIds, weights);

        skipToNextEpoch(1);

        // create bribe in epoch 1
        LR.approve(address(bribeVotingReward), TOKEN_1 * 2);
        bribeVotingReward.notifyRewardAmount((address(LR)), TOKEN_1 * 2);
        vm.stopPrank();

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        // claim before flip but after rewards are re-deposited into bribe
        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1);

        skipToNextEpoch(1);

        // claim after flip
        pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 * 2);
    }

    function testGetRewardWithSingleVoteAndPoke() public {
        skip(1 weeks / 2);

        uint256 reward = TOKEN_1;
        uint256 reward2 = TOKEN_1 * 2;

        // create a bribe in epoch 0
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), reward);
        bribeVotingReward.notifyRewardAmount((address(LR)), reward);

        // vote
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        voter.vote(address(owner), poolIds, weights);
        skip(1);

        uint256 earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, 0);

        skipToNextEpoch(1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1);

        // create a bribe in epoch 1
        LR.approve(address(bribeVotingReward), reward2);
        bribeVotingReward.notifyRewardAmount((address(LR)), reward2);
        vm.stopPrank();
        skip(1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1);
        skip(1 hours);

        voter.poke(address(owner));
        skip(1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1);

        skipToNextEpoch(1);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));

        uint256 total = reward + reward2;
        assertEq(post - pre, total);
    }

    function testGetRewardWithSingleCheckpoint() public {
        skip(1 weeks / 2);

        // create a bribe
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);
        assertEq(LR.balanceOf(address(bribeVotingReward)), TOKEN_1);

        // vote
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        // cannot claim
        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));
        assertEq(post - pre, 0);

        // fwd half a week
        skipToNextEpoch(1);

        pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1);
    }

    function testGetRewardWithSingleCheckpointWithOtherVoter() public {
        skip(1 weeks / 2);

        // create a bribe
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);
        assertEq(LR.balanceOf(address(bribeVotingReward)), TOKEN_1);

        // vote
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();

        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        skipToNextEpoch(1);

        // deliver bribe
        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 / 2);

        pre = LR.balanceOf(address(owner2));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner2), rewards);
        post = LR.balanceOf(address(owner2));
        assertEq(post - pre, TOKEN_1 / 2);
    }

    function testGetRewardWithSingleCheckpointWithOtherStaggeredVoter() public {
        skip(1 weeks / 2);

        // create a bribe
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);
        assertEq(LR.balanceOf(address(bribeVotingReward)), TOKEN_1);

        // vote
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();

        // vote delayed
        skip(1 days);
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        // fwd
        skipToNextEpoch(1);

        // deliver bribe
        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));
        assertGt(post - pre, TOKEN_1 / 2); // 500172176312657261
        uint256 diff = post - pre;

        pre = LR.balanceOf(address(owner2));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner2), rewards);
        post = LR.balanceOf(address(owner2));
        assertLt(post - pre, TOKEN_1 / 2); // 499827823687342738
        uint256 diff2 = post - pre;

        assertEq(diff + diff2, TOKEN_1 - 1); // -1 for rounding
    }

    function testGetRewardWithSkippedClaims() public {
        skip(1 weeks / 2);

        uint256 reward = TOKEN_1; // epoch 0 reward
        uint256 reward2 = TOKEN_1 * 2; // epoch1 reward
        uint256 reward3 = TOKEN_1 * 3; // epoch3 reward

        // create bribe with amount reward in epoch 0
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), reward);
        bribeVotingReward.notifyRewardAmount(address(LR), reward);
        assertEq(LR.balanceOf(address(bribeVotingReward)), reward);

        // vote for pool1
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);

        skipToNextEpoch(1);

        // check reward amount is correct
        uint256 expectedReward = reward / 2;
        uint256 earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, expectedReward);
        earned = bribeVotingReward.earned(address(LR), address(owner2));
        assertEq(earned, expectedReward);

        // create bribe with amount reward2 in epoch 1
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), reward2);
        bribeVotingReward.notifyRewardAmount(address(LR), reward2);
        assertEq(LR.balanceOf(address(bribeVotingReward)), reward + reward2);

        skip(1 hours);

        // vote again for same pool
        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);

        skipToNextEpoch(1);

        expectedReward = (reward + reward2) / 2;
        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, expectedReward);
        earned = bribeVotingReward.earned(address(LR), address(owner2));
        assertEq(earned, expectedReward);

        // create bribe with amount reward3 in epoch 2
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), reward3);
        bribeVotingReward.notifyRewardAmount(address(LR), reward3);
        vm.stopPrank();
        assertEq(LR.balanceOf(address(bribeVotingReward)), reward + reward2 + reward3);
        skip(1 hours);

        // poked into voting for same pool
        voter.poke(address(owner));
        voter.poke(address(owner2));

        skipToNextEpoch(1);

        expectedReward = (reward + reward2 + reward3) / 2;
        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, expectedReward);
        earned = bribeVotingReward.earned(address(LR), address(owner2));
        assertEq(earned, expectedReward);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));
        assertEq(post - pre, expectedReward);

        pre = LR.balanceOf(address(owner2));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner2), rewards);
        post = LR.balanceOf(address(owner2));
        assertEq(post - pre, expectedReward);
    }

    function testCannotClaimRewardForPoolIfPokedButVotedForOtherPool() public {
        skip(1 weeks / 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        // set up votes
        uint160[] memory poolIds = new uint160[](1);
        uint160[] memory poolIds2 = new uint160[](1);
        uint256[] memory weights = new uint256[](1);
        poolIds[0] = poolId1;
        poolIds2[0] = poolId2;
        weights[0] = 10000;

        // create a bribe in epoch 0
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);

        // vote for pool1 in epoch 0
        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);

        skipToNextEpoch(1);

        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 / 2);

        pre = LR.balanceOf(address(owner2));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner2), rewards);
        post = LR.balanceOf(address(owner2));
        assertEq(post - pre, TOKEN_1 / 2);

        skip(1);

        // create a bribe for pool1 in epoch 1
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);
        // create a bribe for pool2 in epoch 1
        LR.approve(address(bribeVotingReward2), TOKEN_1 * 2);
        bribeVotingReward2.notifyRewardAmount(address(LR), TOKEN_1 * 2);
        skip(1 hours);

        // poke causes user 1 to "vote" for pool1
        voter.poke(address(owner));
        skip(1 hours);

        // vote for pool2 in epoch 1
        voter.vote(address(owner), poolIds2, weights);
        vm.stopPrank();

        // go to next epoch
        skipToNextEpoch(1);

        // earned for pool1 should be 0
        uint256 earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, 0);

        // earned for pool1 for owner2 should be full bribe amount
        earned = bribeVotingReward.earned(address(LR), address(owner2));
        assertEq(earned, TOKEN_1);

        // earned for pool2 should be TOKEN_1
        earned = bribeVotingReward2.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1 * 2);

        pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward2.getRewards(address(owner), rewards);
        post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 * 2);
    }

    function testGetRewardWithAlternatingVotes() public {
        skip(1 weeks / 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        // set up votes
        uint160[] memory poolIds = new uint160[](1);
        uint160[] memory poolIds2 = new uint160[](1);
        uint256[] memory weights = new uint256[](1);
        poolIds[0] = poolId1;
        poolIds2[0] = poolId2;
        weights[0] = 10000;

        // create a bribe in epoch 0
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);

        // vote for pool1 in epoch 0
        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);
        skip(1);

        // fwd half a week
        skipToNextEpoch(1);

        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 / 2);

        uint256 earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, 0);
        skip(1);

        // create a bribe for pool1 in epoch 1
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);
        // create a bribe for pool2 in epoch 1
        LR.approve(address(bribeVotingReward2), TOKEN_1 * 2);
        bribeVotingReward2.notifyRewardAmount(address(LR), TOKEN_1 * 2);
        skip(1 hours);

        voter.vote(address(owner), poolIds2, weights);
        vm.stopPrank();
        vm.prank(address(owner3));
        voter.vote(address(owner3), poolIds2, weights);

        // go to next week
        skipToNextEpoch(1 hours + 1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, 0);

        vm.prank(owner);
        voter.vote(address(owner), poolIds, weights);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, 0);
        earned = bribeVotingReward2.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1);

        pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward2.getRewards(address(owner), rewards);
        post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1);
    }

    // same test as above but with some initial checkpoints in place
    function testGetRewardWithAlternatingVotesWithInitialCheckpoints() public {
        skip(1 weeks / 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        // set up votes
        uint160[] memory poolIds = new uint160[](1);
        uint160[] memory poolIds2 = new uint160[](1);
        uint256[] memory weights = new uint256[](1);
        poolIds[0] = poolId1;
        poolIds2[0] = poolId2;
        weights[0] = 10000;

        // add initial checkpoints
        for (uint256 i = 0; i < 5; i++) {
            // vote for pool1 in epoch 0
            vm.prank(owner);
            voter.vote(address(owner), poolIds, weights);
            vm.prank(address(owner2));
            voter.vote(address(owner2), poolIds, weights);

            // fwd half a week
            skipToNextEpoch(1 hours + 1);
        }

        // create a bribe in epoch 0
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);

        // vote for pool1 in epoch 0
        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);
        skip(1);

        // fwd half a week
        skipToNextEpoch(1);

        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 / 2);

        uint256 earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, 0);
        skip(1);

        // create a bribe for pool1 in epoch 1
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);
        // create a bribe for pool2 in epoch 1
        LR.approve(address(bribeVotingReward2), TOKEN_1 * 2);
        bribeVotingReward2.notifyRewardAmount(address(LR), TOKEN_1 * 2);
        skip(1 hours);

        voter.vote(address(owner), poolIds2, weights);
        vm.stopPrank();
        vm.prank(address(owner3));
        voter.vote(address(owner3), poolIds2, weights);

        // go to next week
        skipToNextEpoch(1 hours + 1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, 0);

        vm.prank(owner3);
        voter.vote(address(owner3), poolIds, weights);

        earned = bribeVotingReward.earned(address(LR), address(owner3));
        assertEq(earned, 0);
        earned = bribeVotingReward2.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1);

        pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward2.getRewards(address(owner), rewards);
        post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1);
    }

    function testCannotClaimRewardForPoolIfPokedButReset() public {
        skip(1 weeks / 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        // set up votes
        uint160[] memory poolIds = new uint160[](1);
        uint256[] memory weights = new uint256[](1);
        poolIds[0] = poolId1;
        weights[0] = 10000;

        // create a bribe in epoch 0
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);
        vm.stopPrank();

        // vote for pool1 in epoch 0
        voter.vote(address(owner), poolIds, weights);
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);

        skipToNextEpoch(1);

        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 / 2);
        skip(1);

        // create a bribe for pool1 in epoch 1
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);
        skip(1 hours);

        // poke causes user 1 to "vote" for pool1
        voter.poke(address(owner));
        skip(1);

        // abstain in epoch 1
        voter.reset(address(owner));

        // go to next epoch
        skipToNextEpoch(1);

        // earned for pool1 should be 0
        uint256 earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, 0);
        vm.stopPrank();
    }

    function testGetRewardWithVoteThenPoke() public {
        /// tests poking makes no difference to voting outcome
        skip(1 weeks / 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        // set up votes
        uint160[] memory poolIds = new uint160[](1);
        uint256[] memory weights = new uint256[](1);
        poolIds[0] = poolId1;
        weights[0] = 10000;

        // create a bribe in epoch 0
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);

        // vote for pool1 in epoch 0
        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);

        skipToNextEpoch(1);

        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 / 2);
        skip(1);

        // create a bribe for pool1 in epoch 1
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);
        skip(1 hours);

        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();
        skip(1 hours);

        // get poked an hour later
        voter.poke(address(owner));
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);

        // go to next epoch
        skipToNextEpoch(1);

        // earned for pool1 should be 0
        uint256 earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1 / 2);
    }

    function testGetRewardWithVotesForMultiplePools() public {
        skip(1 weeks / 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        // set up votes
        uint160[] memory poolIds = new uint160[](2);
        uint256[] memory weights = new uint256[](2);
        poolIds[0] = poolId1;
        poolIds[1] = poolId2;
        weights[0] = 2;
        weights[1] = 8;

        // create a bribe in epoch 0 for pool1
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);
        // create a usdc bribe in epoch 1 for pool2
        USDC.approve(address(bribeVotingReward2), USDC_1);
        bribeVotingReward2.notifyRewardAmount(address(USDC), USDC_1);

        // vote for pool1 in epoch 0
        voter.vote(address(owner), poolIds, weights); // 20% to pool1, 80% to pool2
        vm.stopPrank();

        // flip weights around
        weights[0] = 8;
        weights[1] = 2;
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights); // 80% to pool1, 20% to pool2

        skipToNextEpoch(1);

        // check pool1 bribes are correct
        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));
        assertApproxEqAbs(post - pre, TOKEN_1 / 5, 1);

        pre = LR.balanceOf(address(owner2));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner2), rewards);
        post = LR.balanceOf(address(owner2));
        assertEq(post - pre, (TOKEN_1 * 4) / 5);

        // check pool2 bribes are correct
        rewards[0] = address(USDC);
        pre = USDC.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward2.getRewards(address(owner), rewards);
        post = USDC.balanceOf(address(owner));
        assertEq(post - pre, (USDC_1 * 4) / 5);

        pre = USDC.balanceOf(address(owner2));
        vm.prank(address(voter));
        bribeVotingReward2.getRewards(address(owner2), rewards);
        post = USDC.balanceOf(address(owner2));
        assertApproxEqAbs(post - pre, USDC_1 / 5, 1);
    }

    function testCannotGetRewardForNewPoolVotedAfterEpochFlip() public {
        skip(1 weeks / 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        // set up votes
        uint160[] memory poolIds = new uint160[](1);
        uint256[] memory weights = new uint256[](1);
        poolIds[0] = poolId1;
        weights[0] = 10000;

        // create a bribe for pool1 and pool2 in epoch 0
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);
        USDC.approve(address(bribeVotingReward2), USDC_1);
        bribeVotingReward2.notifyRewardAmount(address(USDC), USDC_1);

        // vote for pool1 in epoch 0
        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);

        // owner3 votes for pool2
        poolIds[0] = poolId2;
        vm.prank(address(owner3));
        voter.vote(address(owner3), poolIds, weights);

        // go to next epoch but do not distribute
        skipToNextEpoch(1 hours + 1);

        // vote for pool2 shortly after epoch flips
        voter.vote(address(owner), poolIds, weights);
        skip(1);

        // attempt to claim from initial pool currently voted for fails
        uint256 pre = USDC.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward2.getRewards(address(owner), rewards);
        uint256 post = USDC.balanceOf(address(owner));
        assertEq(post - pre, 0);

        // claim last week's rewards
        pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 / 2);
    }

    function testCannotGetRewardInSameEpochAsVote() public {
        skip(1 weeks / 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        // set up votes
        uint160[] memory poolIds = new uint160[](1);
        uint256[] memory weights = new uint256[](1);
        poolIds[0] = poolId1;
        weights[0] = 10000;

        // create a bribe for pool1 in epoch 0
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);
        skip(1);

        // vote for pool1 in epoch 0
        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);
        skip(1);

        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));
        assertEq(post - pre, 0);

        skipToNextEpoch(1);

        // create a bribe for pool1 in epoch 1
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1 * 2);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1 * 2);
        skip(1 hours);

        // vote for pool1 in epoch 1
        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);
        skip(1);

        // attempt claim again after vote, only get rewards from epoch 0
        pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 / 2);

        skipToNextEpoch(1);

        pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1);
    }

    function testCannotGetRewardInSameEpochAsVoteWithFuzz(uint256 ts) public {
        skipToNextEpoch(1 hours + 1);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        // set up votes
        uint160[] memory poolIds = new uint160[](1);
        uint256[] memory weights = new uint256[](1);
        poolIds[0] = poolId1;
        weights[0] = 10000;

        // create a bribe for pool1 in epoch 0
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);

        // vote for pool1 in epoch 0
        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();
        vm.prank(address(owner2));

        ts = bound(ts, 0, 1 weeks - (1 hours) - 2);
        skipAndRoll(ts);

        assertEq(bribeVotingReward.earned(address(LR), address(owner)), 0);
    }

    function testGetRewardWithVoteAndNotifyRewardInDifferentOrders() public {
        skip(1 weeks / 2);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        // set up votes
        uint160[] memory poolIds = new uint160[](1);
        uint256[] memory weights = new uint256[](1);
        poolIds[0] = poolId1;
        weights[0] = 10000;

        // create a bribe for pool1 in epoch 0
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);
        skip(1 hours);

        // vote for pool1 in epoch 0
        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);
        skip(1);

        uint256 earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, 0);

        skipToNextEpoch(1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1 / 2);
        skip(1 hours);

        // vote first, then create bribe
        voter.vote(address(owner), poolIds, weights);
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);
        skip(1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1 / 2);

        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1 * 2);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1 * 2);
        vm.stopPrank();
        skip(1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1 / 2);

        skipToNextEpoch(1);

        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, (TOKEN_1 * 3) / 2);

        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));
        assertEq(post - pre, (TOKEN_1 * 3) / 2);
    }

    function testDepositAndWithdrawCreatesCheckpoints() public {
        skip(1 weeks / 2);

        uint256 numSupply = bribeVotingReward.supplyNumCheckpoints();
        assertEq(numSupply, 0); // no existing checkpoints

        (uint256 ts, uint256 balance) = bribeVotingReward.checkpoints(address(owner), 0);
        assertEq(ts, 0);
        assertEq(balance, 0);

        // deposit by voting
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;
        voter.vote(address(owner), poolIds, weights);

        uint256 expectedTs = block.timestamp;
        uint256 expectedBal = escrow.balanceOf(address(owner));

        // check single user and supply checkpoint created
        numSupply = bribeVotingReward.supplyNumCheckpoints();
        assertEq(numSupply, 1);
        (uint256 sTs, uint256 sBalance) = bribeVotingReward.supplyCheckpoints(0);
        assertEq(sTs, expectedTs);
        assertEq(sBalance, expectedBal);

        (ts, balance) = bribeVotingReward.checkpoints(address(owner), 0);
        assertEq(ts, expectedTs);
        assertEq(balance, expectedBal);

        skipToNextEpoch(1 hours + 1);

        // withdraw by voting for other pool
        poolIds[0] = poolId2;
        voter.vote(address(owner), poolIds, weights);

        numSupply = bribeVotingReward.supplyNumCheckpoints();
        assertEq(numSupply, 2);

        expectedTs = block.timestamp;

        // check new checkpoint created
        (ts, balance) = bribeVotingReward.checkpoints(address(owner), 1);
        assertEq(ts, expectedTs);
        assertEq(balance, 0); // balance 0 on withdraw
        (sTs, sBalance) = bribeVotingReward.supplyCheckpoints(1);
        assertEq(sTs, expectedTs);
        assertEq(sBalance, 0);
    }

    function testDepositAndWithdrawWithinSameEpochOverwritesCheckpoints() public {
        skip(1 weeks / 2);

        // test vote and poke overwrites checkpoints
        // deposit by voting
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        voter.vote(address(owner), poolIds, weights);

        uint256 expectedTs = block.timestamp;
        uint256 expectedBal = escrow.balanceOf(address(owner));

        // check single user and supply checkpoint created
        uint256 numSupply = bribeVotingReward.supplyNumCheckpoints();
        assertEq(numSupply, 1);

        (uint256 sTs, uint256 sBalance) = bribeVotingReward.supplyCheckpoints(0);
        assertEq(sTs, expectedTs);
        assertEq(sBalance, expectedBal);

        (uint256 ts, uint256 balance) = bribeVotingReward.checkpoints(address(owner), 0);
        assertEq(ts, expectedTs);
        assertEq(balance, expectedBal);

        // poked after one day. any checkpoints created should overwrite prior checkpoints.
        skip(1 days);
        voter.poke(address(owner));

        expectedTs = block.timestamp;
        expectedBal = escrow.balanceOf(address(owner));

        numSupply = bribeVotingReward.supplyNumCheckpoints();
        assertEq(numSupply, 1);
        (sTs, sBalance) = bribeVotingReward.supplyCheckpoints(0);
        assertEq(sTs, expectedTs);
        assertEq(sBalance, expectedBal);

        (ts, balance) = bribeVotingReward.checkpoints(address(owner), 0);
        assertEq(ts, expectedTs);
        assertEq(sBalance, expectedBal);

        // check poke and reset/withdraw overwrites checkpoints
        skipToNextEpoch(1 hours + 1);

        // poke to create a checkpoint in new epoch
        voter.poke(address(owner));

        // check old checkpoints are not overridden
        numSupply = bribeVotingReward.supplyNumCheckpoints();
        assertEq(numSupply, 2);
        (sTs, sBalance) = bribeVotingReward.supplyCheckpoints(0);
        assertEq(sTs, expectedTs);
        assertEq(sBalance, expectedBal);

        (ts, balance) = bribeVotingReward.checkpoints(address(owner), 0);
        assertEq(ts, expectedTs);
        assertEq(sBalance, expectedBal);

        expectedTs = block.timestamp;
        expectedBal = escrow.balanceOf(address(owner));

        numSupply = bribeVotingReward.supplyNumCheckpoints();
        assertEq(numSupply, 2);
        (sTs, sBalance) = bribeVotingReward.supplyCheckpoints(1);
        assertEq(sTs, expectedTs);
        assertEq(sBalance, expectedBal);

        (ts, balance) = bribeVotingReward.checkpoints(address(owner), 1);
        assertEq(ts, expectedTs);
        assertEq(sBalance, expectedBal);

        // withdraw via reset after one day, expect supply to be zero
        skip(1 days);
        voter.reset(address(owner));

        expectedTs = block.timestamp;

        numSupply = bribeVotingReward.supplyNumCheckpoints();
        assertEq(numSupply, 2);
        (sTs, sBalance) = bribeVotingReward.supplyCheckpoints(1);
        assertEq(sTs, expectedTs);
        assertEq(sBalance, 0);

        (ts, balance) = bribeVotingReward.checkpoints(address(owner), 1);
        assertEq(ts, expectedTs);
        assertEq(sBalance, 0);
    }

    function testDepositFromManyUsersInSameTimestampOverwritesSupplyCheckpoint() public {
        skip(1 weeks / 2);

        // deposit by voting
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        // test two (supply) checkpoints at same ts
        voter.vote(owners[0], poolIds, weights);

        uint256 ownerBal = escrow.balanceOf(owners[0]);
        uint256 owner2Bal = escrow.balanceOf(owners[1]);
        uint256 totalSupply = ownerBal + owner2Bal;

        // check single user and supply checkpoint created
        uint256 numSupply = bribeVotingReward.supplyNumCheckpoints();
        assertEq(numSupply, 1);
        (uint256 sTs, uint256 sBalance) = bribeVotingReward.supplyCheckpoints(0);
        assertEq(sTs, block.timestamp);
        assertEq(sBalance, ownerBal);

        (uint256 ts, uint256 balance) = bribeVotingReward.checkpoints(address(owner), 0);
        assertEq(ts, block.timestamp);
        assertEq(balance, ownerBal);

        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);

        numSupply = bribeVotingReward.supplyNumCheckpoints();
        assertEq(numSupply, 1);
        (sTs, sBalance) = bribeVotingReward.supplyCheckpoints(0);
        assertEq(sTs, block.timestamp);
        assertEq(sBalance, totalSupply);

        (ts, balance) = bribeVotingReward.checkpoints(address(owner2), 0);
        assertEq(ts, block.timestamp);
        assertEq(balance, owner2Bal);
    }

    function testGetRewardWithSeparateRewardClaims() public {
        skip(1 weeks / 2);

        // create a LR bribe
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);

        // vote
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;
        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();

        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);

        skipToNextEpoch(1);

        // create usdc bribe, vote passively this epoch
        vm.startPrank(owner);
        USDC.approve(address(bribeVotingReward), USDC_1);
        bribeVotingReward.notifyRewardAmount(address(USDC), USDC_1);
        vm.stopPrank();

        uint256 earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, TOKEN_1 / 2);

        earned = bribeVotingReward.earned(address(USDC), address(owner));
        assertEq(earned, 0);

        skipToNextEpoch(1);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        // claim LR reward first
        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 / 2);

        skipToNextEpoch(1);

        // claim USDC the week after
        rewards[0] = address(USDC);
        pre = USDC.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        post = USDC.balanceOf(address(owner));
        assertEq(post - pre, USDC_1 / 2);
    }

    function testGetRewardWithVotesForMultiplePoolsMinusDaoFees() public {
        skip(1 weeks / 2);

        // rewards
        address[] memory rewards = new address[](1);

        // set up votes
        uint160[] memory poolIds = new uint160[](3);
        uint256[] memory weights = new uint256[](3);
        poolIds[0] = poolId1;
        poolIds[1] = poolId2;
        poolIds[2] = poolId3;

        uint160[] memory daoFeeUpdatePools = new uint160[](1);
        daoFeeUpdatePools[0] = poolId1;

        // Set Dao fee on fees voting rewards
        vm.startPrank(dao);
        voter.setPoolsVotingRewardsDaoFee(daoFeeUpdatePools, 0, 50);
        vm.stopPrank();

        uint256 preBalanceLRDao = LR.balanceOf(dao);
        uint256 preBalanceUSDCDao = USDC.balanceOf(dao);
        uint256 preBalanceDAIDao = DAI.balanceOf(dao);

        // create a bribe in epoch 0 for pool1
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);
        // create a usdc bribe in epoch 0 for pool2
        USDC.approve(address(bribeVotingReward2), USDC_1);
        bribeVotingReward2.notifyRewardAmount(address(USDC), USDC_1);
        // create a bribe in epoch 0 for pool3
        DAI.approve(address(bribeVotingReward3), TOKEN_1);
        bribeVotingReward3.notifyRewardAmount(address(DAI), TOKEN_1);

        {
            // DAO Fees for pool1
            uint256 postBalanceLRDao = LR.balanceOf(dao);
            assertEq(postBalanceLRDao - preBalanceLRDao, ((5 * TOKEN_1) / 1000));

            // DAO Fees for pool2
            uint256 postBalanceUSDCDao = USDC.balanceOf(dao);
            assertEq(postBalanceUSDCDao - preBalanceUSDCDao, 0);

            // DAO Fees for pool3
            uint256 postBalanceDAIDao = DAI.balanceOf(dao);
            assertEq(postBalanceDAIDao - preBalanceDAIDao, (TOKEN_1 / 100));
        }

        {
            // vote for pools in epoch 0
            weights[0] = 3;
            weights[1] = 2;
            weights[2] = 5;
            voter.vote(address(owner), poolIds, weights); // 30% to pool1, 20% to pool2, 50% to pool3
            vm.stopPrank();

            // flip weights around
            weights[0] = 2;
            weights[1] = 5;
            weights[2] = 3;
            vm.prank(address(owner2));
            voter.vote(address(owner2), poolIds, weights); // 20% to pool1, 50% to pool2, 30% to pool3

            // flip weights around
            weights[0] = 5;
            weights[1] = 3;
            weights[2] = 2;
            vm.prank(address(owner3));
            voter.vote(address(owner3), poolIds, weights); // 50% to pool1, 30% to pool2, 20% to pool3
        }
        skipToNextEpoch(1);

        // Bribe rewards for pool1
        rewards[0] = address(LR);
        uint256 preBalanceOwner = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 postBalanceOwner = LR.balanceOf(address(owner));
        assertApproxEqAbs(postBalanceOwner - preBalanceOwner, (995 * ((3 * TOKEN_1) / 10)) / 1000, 1);

        uint256 preBalanceOwner2 = LR.balanceOf(address(owner2));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner2), rewards);
        uint256 postBalanceOwner2 = LR.balanceOf(address(owner2));
        assertApproxEqAbs(postBalanceOwner2 - preBalanceOwner2, (995 * (TOKEN_1 / 5)) / 1000, 1);

        uint256 preBalanceOwner3 = LR.balanceOf(address(owner3));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner3), rewards);
        uint256 postBalanceOwner3 = LR.balanceOf(address(owner3));
        assertApproxEqAbs(postBalanceOwner3 - preBalanceOwner3, (995 * (TOKEN_1 / 2)) / 1000, 1);

        // Bribe rewards for pool2
        rewards[0] = address(USDC);
        preBalanceOwner = USDC.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward2.getRewards(address(owner), rewards);
        postBalanceOwner = USDC.balanceOf(address(owner));
        assertApproxEqAbs(postBalanceOwner - preBalanceOwner, USDC_1 / 5, 1);

        preBalanceOwner2 = USDC.balanceOf(address(owner2));
        vm.prank(address(voter));
        bribeVotingReward2.getRewards(address(owner2), rewards);
        postBalanceOwner2 = USDC.balanceOf(address(owner2));
        assertApproxEqAbs(postBalanceOwner2 - preBalanceOwner2, USDC_1 / 2, 1);

        preBalanceOwner3 = USDC.balanceOf(address(owner3));
        vm.prank(address(voter));
        bribeVotingReward2.getRewards(address(owner3), rewards);
        postBalanceOwner3 = USDC.balanceOf(address(owner3));
        assertApproxEqAbs(postBalanceOwner3 - preBalanceOwner3, (3 * USDC_1) / 10, 1);

        // Bribe rewards for pool3
        rewards[0] = address(DAI);
        preBalanceOwner = DAI.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward3.getRewards(address(owner), rewards);
        postBalanceOwner = DAI.balanceOf(address(owner));
        assertApproxEqAbs(postBalanceOwner - preBalanceOwner, (99 * (TOKEN_1 / 2)) / 100, 1);

        preBalanceOwner2 = DAI.balanceOf(address(owner2));
        vm.prank(address(voter));
        bribeVotingReward3.getRewards(address(owner2), rewards);
        postBalanceOwner2 = DAI.balanceOf(address(owner2));
        assertApproxEqAbs(postBalanceOwner2 - preBalanceOwner2, (99 * ((3 * TOKEN_1) / 10)) / 100, 1);

        preBalanceOwner3 = DAI.balanceOf(address(owner3));
        vm.prank(address(voter));
        bribeVotingReward3.getRewards(address(owner3), rewards);
        postBalanceOwner3 = DAI.balanceOf(address(owner3));
        assertApproxEqAbs(postBalanceOwner3 - preBalanceOwner3, (99 * (TOKEN_1 / 5)) / 100, 1);
    }

    function testCannotNotifyRewardWithZeroAmount() public {
        vm.startPrank(owner);
        vm.expectRevert(IVotingReward.ZeroAmount.selector);
        bribeVotingReward.notifyRewardAmount(address(LR), 0);
        vm.stopPrank();
    }

    function testCannotNotifyRewardWithUnwhitelistedToken() public {
        address token = address(new MockERC20("TEST", "TEST", 18));

        assertEq(voter.isWhitelistedBribeToken(token), false);

        vm.startPrank(owner);
        vm.expectRevert(IVotingReward.NotWhitelistedReward.selector);
        bribeVotingReward.notifyRewardAmount(token, TOKEN_1);
        vm.stopPrank();
    }

    function testCannotNotifyRewardForBannedPool() public {
        vm.prank(emergencyCouncil);
        voter.banVote(poolId1);

        vm.startPrank(owner);
        vm.expectRevert(IVotingReward.PoolBanned.selector);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);
        vm.stopPrank();
    }

    function testNotifyRewardAmountWithWhiteListedToken() public {
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        uint256 pre = LR.balanceOf(address(owner));
        vm.expectEmit(true, true, true, true, address(bribeVotingReward));
        emit NotifyReward(address(owner), address(LR), VelodromeTimeLibrary.epochStart(block.timestamp), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);
        vm.stopPrank();
        uint256 post = LR.balanceOf(address(owner));

        assertEq(bribeVotingReward.isReward(address(LR)), true);
        assertEq(
            bribeVotingReward.tokenRewardsPerEpoch(address(LR), VelodromeTimeLibrary.epochStart(block.timestamp)),
            TOKEN_1
        );
        assertEq(pre - post, TOKEN_1);
        assertEq(LR.balanceOf(address(bribeVotingReward)), TOKEN_1);

        skip(1 hours);
        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1 * 2);
        pre = LR.balanceOf(address(owner));
        vm.expectEmit(true, true, true, true, address(bribeVotingReward));
        emit NotifyReward(address(owner), address(LR), VelodromeTimeLibrary.epochStart(block.timestamp), TOKEN_1 * 2);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1 * 2);
        vm.stopPrank();
        post = LR.balanceOf(address(owner));

        assertEq(
            bribeVotingReward.tokenRewardsPerEpoch(address(LR), VelodromeTimeLibrary.epochStart(block.timestamp)),
            TOKEN_1 * 3
        );
        assertEq(pre - post, TOKEN_1 * 2);
        assertEq(LR.balanceOf(address(bribeVotingReward)), TOKEN_1 * 3);
    }

    function testGetAllRewards() public {
        address[] memory _rewards = bribeVotingReward.getAllRewards();
        assertEq(_rewards.length, 0);

        vm.startPrank(owner);
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);
        vm.stopPrank();

        _rewards = bribeVotingReward.getAllRewards();
        assertEq(_rewards.length, 1);
        assertEq(_rewards[0], address(LR));

        vm.startPrank(owner);
        USDC.approve(address(bribeVotingReward), USDC_1 * 2);
        bribeVotingReward.notifyRewardAmount(address(USDC), USDC_1 * 2);
        vm.stopPrank();

        _rewards = bribeVotingReward.getAllRewards();
        assertEq(_rewards.length, 2);
        assertEq(_rewards[0], address(LR));
        assertEq(_rewards[1], address(USDC));
    }
}
