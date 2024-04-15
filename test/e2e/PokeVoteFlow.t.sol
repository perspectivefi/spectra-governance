// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "./ExtendedBaseTest.sol";

contract PokeVoteFlow is ExtendedBaseTest {
    function _setUp() public override {
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);
        vm.startPrank(address(owner2), address(owner2));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);
        vm.stopPrank();
        vm.startPrank(address(owner3), address(owner3));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);
        vm.stopPrank();

        // create shorter lock for owner4
        vm.startPrank(address(owner4), address(owner4));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME / 4 + block.timestamp);
        vm.stopPrank();
        skip(1);
    }

    function testPokeVoteBribeVotingRewardFlow() public {
        skip(1 hours + 1);

        // set up votes and rewards
        uint160[] memory poolIds = new uint160[](2);
        poolIds[0] = poolId1;
        poolIds[1] = poolId2;
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5000;
        weights[1] = 5000;
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);
        address[] memory usdcRewards = new address[](1);
        usdcRewards[0] = address(USDC);

        uint256 currentBribe = 0;
        uint256 usdcBribe = 0;

        /// epoch zero
        // set up initial votes for multiple pools
        currentBribe = TOKEN_1;
        usdcBribe = USDC_1;
        vm.startPrank(owner);
        _createBribeWithAmount(bribeVotingReward, address(LR), currentBribe);
        _createBribeWithAmount(bribeVotingReward2, address(USDC), usdcBribe);
        voter.vote(address(owner), poolIds, weights);
        vm.startPrank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);

        skipToNextEpoch(1);

        // skip claiming this epoch
        uint256 earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, currentBribe / 2);
        earned = bribeVotingReward2.earned(address(USDC), address(owner));
        assertEq(earned, usdcBribe / 2);
        earned = bribeVotingReward.earned(address(LR), address(owner2));
        assertEq(earned, currentBribe / 2);
        earned = bribeVotingReward2.earned(address(USDC), address(owner2));
        assertEq(earned, usdcBribe / 2);

        skip(1);

        // test pokes before final poke have no impact
        currentBribe = TOKEN_1 * 2;
        usdcBribe = USDC_1 * 2;
        _createBribeWithAmount(bribeVotingReward, address(LR), currentBribe);
        _createBribeWithAmount(bribeVotingReward2, address(USDC), usdcBribe);
        skip(1 hours);

        // owner gets poked many times
        for (uint256 i = 0; i < 5; i++) {
            voter.poke(address(owner));
            skip(1 days);
        }

        // final poke occurs at same time, expect rewards to be the same
        voter.poke(address(owner));
        voter.poke(address(owner2));

        skipToNextEpoch(1);

        // check pool1 bribe (LR) is correct
        uint256 pre = LR.balanceOf(address(owner));
        vm.startPrank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));
        assertEq(post - pre, (TOKEN_1 * 3) / 2);

        pre = LR.balanceOf(address(owner2));
        vm.startPrank(address(voter));
        bribeVotingReward.getRewards(address(owner2), rewards);
        post = LR.balanceOf(address(owner2));
        assertEq(post - pre, (TOKEN_1 * 3) / 2);

        // check pool2 bribe (usdc) is correct
        uint256 usdcPre = USDC.balanceOf(address(owner));
        vm.startPrank(address(voter));
        bribeVotingReward2.getRewards(address(owner), usdcRewards);
        uint256 usdcPost = USDC.balanceOf(address(owner));
        assertEq(usdcPost - usdcPre, (USDC_1 * 3) / 2);

        usdcPre = USDC.balanceOf(address(owner2));
        vm.startPrank(address(voter));
        bribeVotingReward2.getRewards(address(owner2), usdcRewards);
        usdcPost = USDC.balanceOf(address(owner2));
        assertEq(usdcPost - usdcPre, (USDC_1 * 3) / 2);
        vm.stopPrank();

        // test pokes before final vote have no impact
        currentBribe = TOKEN_1 * 3;
        usdcBribe = USDC_1 * 3;
        vm.startPrank(owner);
        _createBribeWithAmount(bribeVotingReward, address(LR), currentBribe);
        _createBribeWithAmount(bribeVotingReward2, address(USDC), usdcBribe);
        vm.stopPrank();
        skip(1 hours);

        // owner gets poked many times
        for (uint256 i = 0; i < 5; i++) {
            voter.poke(address(owner));
            skip(1 days);
        }
        skip(1 hours);

        // final vote occurs at same time, expect rewards to be the same
        vm.startPrank(owner);
        voter.vote(address(owner), poolIds, weights);
        vm.startPrank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);
        vm.stopPrank();
        skipToNextEpoch(1);

        pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        post = LR.balanceOf(address(owner));
        assertEq(post - pre, (TOKEN_1 * 3) / 2);

        pre = LR.balanceOf(address(owner2));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner2), rewards);
        post = LR.balanceOf(address(owner2));
        assertEq(post - pre, (TOKEN_1 * 3) / 2);

        usdcPre = USDC.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward2.getRewards(address(owner), usdcRewards);
        usdcPost = USDC.balanceOf(address(owner));
        assertEq(usdcPost - usdcPre, (USDC_1 * 3) / 2);

        usdcPre = USDC.balanceOf(address(owner2));
        vm.prank(address(voter));
        bribeVotingReward2.getRewards(address(owner2), usdcRewards);
        usdcPost = USDC.balanceOf(address(owner2));
        assertEq(usdcPost - usdcPre, (USDC_1 * 3) / 2);

        // test only last poke after vote is counted
        // switch to voting for pools 2 and 3
        currentBribe = TOKEN_1 * 4;
        usdcBribe = USDC_1 * 4;
        poolIds[0] = poolId2;
        poolIds[1] = poolId3;
        vm.startPrank(owner);
        _createBribeWithAmount(bribeVotingReward, address(LR), currentBribe);
        _createBribeWithAmount(bribeVotingReward2, address(LR), currentBribe);
        _createBribeWithAmount(bribeVotingReward3, address(USDC), usdcBribe);
        vm.stopPrank();
        skip(1);

        uint160[] memory singlePool = new uint160[](1);
        singlePool[0] = poolId1;
        uint256[] memory singleWeight = new uint256[](1);
        singleWeight[0] = 1;

        skip(1 hours);
        // deposit into pool1 to provide supply
        vm.prank(address(owner3));
        voter.vote(address(owner3), singlePool, singleWeight);
        vm.prank(owner);
        voter.vote(address(owner), poolIds, weights);
        skip(1 days);

        // owner is poked at same time as owner2 votes, so rewards should be equal
        voter.poke(address(owner));
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);

        skipToNextEpoch(1);

        // check no bribes from pool1
        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, 0);
        earned = bribeVotingReward.earned(address(LR), address(owner2));
        assertEq(earned, 0);

        pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward2.getRewards(address(owner), rewards);
        post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 * 2);

        pre = LR.balanceOf(address(owner2));
        vm.prank(address(voter));
        bribeVotingReward2.getRewards(address(owner2), rewards);
        post = LR.balanceOf(address(owner2));
        assertEq(post - pre, TOKEN_1 * 2);

        usdcPre = USDC.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward3.getRewards(address(owner), usdcRewards);
        usdcPost = USDC.balanceOf(address(owner));
        assertEq(usdcPost - usdcPre, (99 * (USDC_1 * 2)) / 100);

        usdcPre = USDC.balanceOf(address(owner2));
        vm.prank(address(voter));
        bribeVotingReward3.getRewards(address(owner2), usdcRewards);
        usdcPost = USDC.balanceOf(address(owner2));
        assertEq(usdcPost - usdcPre, (99 * (USDC_1 * 2)) / 100);

        // test before and after voting accrues votes correctly
        // switch back to voting for pool1 and pool2
        currentBribe = TOKEN_1 * 5;
        usdcBribe = USDC_1 * 5;
        poolIds[0] = poolId1;
        poolIds[1] = poolId2;
        vm.startPrank(owner);
        _createBribeWithAmount(bribeVotingReward, address(LR), currentBribe);
        _createBribeWithAmount(bribeVotingReward2, address(USDC), usdcBribe);
        _createBribeWithAmount(bribeVotingReward3, address(LR), currentBribe);
        vm.stopPrank();
        skip(1 hours);

        // deposit into pool3 to provide supply
        singlePool[0] = poolId3;
        vm.prank(address(owner3));
        voter.vote(address(owner3), singlePool, singleWeight);

        // get poked prior to vote (will 'vote' for pool2, pool3)
        for (uint256 i = 0; i < 5; i++) {
            skip(1 hours);
            voter.poke(address(owner));
        }
        skip(1 hours);

        // vote for pool1, pool2
        vm.prank(owner);
        voter.vote(address(owner), poolIds, weights);

        // get poked after vote (will 'vote' for pool1, pool2)
        for (uint256 i = 0; i < 5; i++) {
            skip(1 hours);
            voter.poke(address(owner));
        }

        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);

        skipToNextEpoch(1);

        // check no bribes from pool3
        earned = bribeVotingReward3.earned(address(LR), address(owner));
        assertEq(earned, 0);
        earned = bribeVotingReward3.earned(address(LR), address(owner2));
        assertEq(earned, 0);

        // check other bribes are correct
        pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        post = LR.balanceOf(address(owner));
        assertEq(post - pre, (TOKEN_1 * 5) / 2);

        pre = LR.balanceOf(address(owner2));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner2), rewards);
        post = LR.balanceOf(address(owner2));
        assertEq(post - pre, (TOKEN_1 * 5) / 2);

        usdcPre = USDC.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward2.getRewards(address(owner), usdcRewards);
        usdcPost = USDC.balanceOf(address(owner));
        assertEq(usdcPost - usdcPre, (USDC_1 * 5) / 2);

        usdcPre = USDC.balanceOf(address(owner2));
        vm.prank(address(voter));
        bribeVotingReward2.getRewards(address(owner2), usdcRewards);
        usdcPost = USDC.balanceOf(address(owner2));
        assertEq(usdcPost - usdcPre, (USDC_1 * 5) / 2);
    }
}
