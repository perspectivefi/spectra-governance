// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "./ExtendedBaseTest.sol";

contract SimpleBribeVotingRewardFlow is ExtendedBaseTest {
    function _setUp() public override {
        skip(1 hours);
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
        escrow.create_lock(TOKEN_1, (MAXTIME / 4) + block.timestamp);
        vm.stopPrank();
        skip(1);
    }

    function testMultiEpochBribeVotingRewardFlow() public {
        // set up votes and rewards
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;
        address[] memory rewards = new address[](2);
        rewards[0] = address(LR);
        rewards[1] = address(USDC);

        // test with both LR & USDC throughout to account for different decimals

        /// epoch zero
        // test two voters with differing balances
        // owner + owner 4 votes
        // owner has max lock time
        // owner4 has quarter of max lock time
        uint256 currentBribe = TOKEN_1;
        uint256 usdcBribe = USDC_1;
        vm.startPrank(owner);
        _createBribeWithAmount(bribeVotingReward, address(LR), currentBribe);
        _createBribeWithAmount(bribeVotingReward, address(USDC), usdcBribe);
        voter.vote(address(owner), poolIds, weights); // balance: 997203164581747618
        vm.stopPrank();
        vm.prank(address(owner4));
        voter.vote(address(owner4), poolIds, weights); // balance: 249257959143917218
        skipToNextEpoch(1);

        /// epoch one
        // expect distributions to be:
        // ~4 parts to owner
        // ~1 part to owner

        // owner share: 997203164581747618 / (997203164581747618 + 249257959143917218) ~= .8000275
        uint256 pre = LR.balanceOf(address(owner));
        uint256 usdcPre = USDC.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        uint256 post = LR.balanceOf(address(owner));
        uint256 usdcPost = USDC.balanceOf(address(owner));
        assertApproxEqRel(post - pre, (currentBribe * 8000275) / 10000000, 1e13);
        assertApproxEqRel(usdcPost - usdcPre, (usdcBribe * 8000275) / 10000000, 1e13);

        // owner4 share: 249257959143917218 / (997203164581747618 + 249257959143917218) ~= .1999725
        pre = LR.balanceOf(address(owner4));
        usdcPre = USDC.balanceOf(address(owner4));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner4), rewards);
        post = LR.balanceOf(address(owner4));
        usdcPost = USDC.balanceOf(address(owner4));
        assertApproxEqRel(post - pre, (currentBribe * 1999725) / 10000000, 1e13);
        assertApproxEqRel(usdcPost - usdcPre, (usdcBribe * 1999725) / 10000000, 1e13);

        // test bribe delivered late in the week
        skip(1 weeks / 2);
        currentBribe = TOKEN_1 * 2;
        usdcBribe = USDC_1 * 2;
        vm.startPrank(owner);
        _createBribeWithAmount(bribeVotingReward, address(LR), currentBribe);
        _createBribeWithAmount(bribeVotingReward, address(USDC), usdcBribe);
        vm.stopPrank();
        skip(1);

        vm.prank(owner);
        voter.vote(address(owner), poolIds, weights);
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);
        vm.prank(address(owner4));
        voter.reset(address(owner4));

        /// epoch two
        skipToNextEpoch(1);

        pre = LR.balanceOf(address(owner));
        usdcPre = USDC.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        post = LR.balanceOf(address(owner));
        usdcPost = USDC.balanceOf(address(owner));
        assertEq(post - pre, currentBribe / 2);
        assertEq(usdcPost - usdcPre, usdcBribe / 2);

        pre = LR.balanceOf(address(owner2));
        usdcPre = USDC.balanceOf(address(owner2));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner2), rewards);
        post = LR.balanceOf(address(owner2));
        usdcPost = USDC.balanceOf(address(owner2));
        assertEq(post - pre, currentBribe / 2);
        assertEq(usdcPost - usdcPre, usdcBribe / 2);

        // test deferred claiming of bribes
        uint256 deferredBribe = TOKEN_1 * 3;
        uint256 deferredUsdcBribe = USDC_1 * 3;
        vm.startPrank(owner);
        _createBribeWithAmount(bribeVotingReward, address(LR), deferredBribe);
        _createBribeWithAmount(bribeVotingReward, address(USDC), deferredUsdcBribe);
        vm.stopPrank();
        skip(1 hours);

        vm.prank(owner);
        voter.vote(address(owner), poolIds, weights);
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights);

        /// epoch three
        skipToNextEpoch(1);

        // test multiple reward tokens for pool2
        currentBribe = TOKEN_1 * 4;
        usdcBribe = USDC_1 * 4;
        vm.startPrank(owner);
        _createBribeWithAmount(bribeVotingReward2, address(LR), currentBribe);
        _createBribeWithAmount(bribeVotingReward2, address(USDC), usdcBribe);
        vm.stopPrank();
        skip(1);

        // skip claiming this epoch, but check earned
        uint256 earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, deferredBribe / 2);
        earned = bribeVotingReward.earned(address(USDC), address(owner));
        assertEq(earned, deferredUsdcBribe / 2);
        earned = bribeVotingReward.earned(address(LR), address(owner2));
        assertEq(earned, deferredBribe / 2);
        earned = bribeVotingReward.earned(address(USDC), address(owner2));
        assertEq(earned, deferredUsdcBribe / 2);
        skip(1 hours);

        // vote for pool2 instead with owner3
        poolIds[0] = poolId2;
        vm.prank(owner);
        voter.vote(address(owner), poolIds, weights);
        vm.prank(address(owner3));
        voter.vote(address(owner3), poolIds, weights);

        /// epoch four
        skipToNextEpoch(1);

        // claim for first voter
        pre = LR.balanceOf(address(owner));
        usdcPre = USDC.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward2.getRewards(address(owner), rewards);
        post = LR.balanceOf(address(owner));
        usdcPost = USDC.balanceOf(address(owner));
        assertEq(post - pre, currentBribe / 2);
        assertEq(usdcPost - usdcPre, usdcBribe / 2);

        // claim for second voter
        pre = LR.balanceOf(address(owner3));
        usdcPre = USDC.balanceOf(address(owner3));
        vm.prank(address(voter));
        bribeVotingReward2.getRewards(address(owner3), rewards);
        post = LR.balanceOf(address(owner3));
        usdcPost = USDC.balanceOf(address(owner3));
        assertEq(post - pre, currentBribe / 2);
        assertEq(usdcPost - usdcPre, usdcBribe / 2);

        // claim deferred bribe
        pre = LR.balanceOf(address(owner));
        usdcPre = USDC.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        post = LR.balanceOf(address(owner));
        usdcPost = USDC.balanceOf(address(owner));
        assertEq(post - pre, deferredBribe / 2);
        assertEq(usdcPost - usdcPre, deferredUsdcBribe / 2);

        pre = LR.balanceOf(address(owner2));
        usdcPre = USDC.balanceOf(address(owner2));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner2), rewards);
        post = LR.balanceOf(address(owner2));
        usdcPost = USDC.balanceOf(address(owner2));
        assertEq(post - pre, deferredBribe / 2);
        assertEq(usdcPost - usdcPre, deferredUsdcBribe / 2);

        // test staggered votes
        currentBribe = TOKEN_1 * 5;
        usdcBribe = USDC_1 * 5;
        vm.startPrank(owner);
        _createBribeWithAmount(bribeVotingReward, address(LR), currentBribe);
        _createBribeWithAmount(bribeVotingReward, address(USDC), usdcBribe);
        vm.stopPrank();
        skip(1 hours);

        // owner re-locks to max time, is currently 4 weeks ahead
        vm.prank(owner, owner);
        escrow.increase_unlock_time(MAXTIME + block.timestamp);

        poolIds[0] = poolId1;
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights); // balance: 958847016055216409
        skip(1 days);
        vm.prank(owner);
        voter.vote(address(owner), poolIds, weights); // balance: 995833317423021209

        /// epoch five
        skipToNextEpoch(1);

        // owner share: 995833317423021209 / (995833317423021209 + 958847016055216409) ~= .5094610
        pre = LR.balanceOf(address(owner));
        usdcPre = USDC.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        post = LR.balanceOf(address(owner));
        usdcPost = USDC.balanceOf(address(owner));
        assertApproxEqRel(post - pre, (currentBribe * 5094610) / 10000000, PRECISION);
        assertApproxEqRel(usdcPost - usdcPre, (usdcBribe * 5094610) / 10000000, PRECISION);

        // owner2 share: 958847016055216409 / (995833317423021209 + 958847016055216409) ~= .4905390
        pre = LR.balanceOf(address(owner2));
        usdcPre = USDC.balanceOf(address(owner2));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner2), rewards);
        post = LR.balanceOf(address(owner2));
        usdcPost = USDC.balanceOf(address(owner2));
        assertApproxEqRel(post - pre, (currentBribe * 4905390) / 10000000, PRECISION);
        assertApproxEqRel(usdcPost - usdcPre, (usdcBribe * 4905390) / 10000000, PRECISION);

        currentBribe = TOKEN_1 * 6;
        usdcBribe = USDC_1 * 6;
        vm.startPrank(owner);
        _createBribeWithAmount(bribeVotingReward, address(LR), currentBribe);
        _createBribeWithAmount(bribeVotingReward, address(USDC), usdcBribe);
        vm.stopPrank();

        // test votes with different vote size
        // owner2 increases amount
        vm.startPrank(address(owner2), address(owner2));
        APW.approve(address(escrow), TOKEN_1);
        escrow.increase_amount(TOKEN_1);
        vm.stopPrank();

        skip(1 hours);

        vm.prank(owner);
        voter.vote(address(owner), poolIds, weights); // balance: 987614139341286809
        vm.prank(address(owner2));
        voter.vote(address(owner2), poolIds, weights); // balance: 1898515949979590817

        /// epoch six
        skipToNextEpoch(1);

        // owner share: 987614139341286809 / (987614139341286809 + 1898515949979590817) ~= .3421932
        pre = LR.balanceOf(address(owner));
        usdcPre = USDC.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        post = LR.balanceOf(address(owner));
        usdcPost = USDC.balanceOf(address(owner));
        assertApproxEqRel(post - pre, (currentBribe * 3421932) / 10000000, 1e15); // 3 decimal places
        assertApproxEqRel(usdcPost - usdcPre, (usdcBribe * 3421932) / 10000000, 1e15);

        // owner2 share: 1898515949979590817 / (987614139341286809 + 1898515949979590817) ~= .6578068
        pre = LR.balanceOf(address(owner2));
        usdcPre = USDC.balanceOf(address(owner2));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner2), rewards);
        post = LR.balanceOf(address(owner2));
        usdcPost = USDC.balanceOf(address(owner2));
        assertApproxEqRel(post - pre, (currentBribe * 6578068) / 10000000, 1e15);
        assertApproxEqRel(usdcPost - usdcPre, (usdcBribe * 6578068) / 10000000, 1e15);

        skip(1 hours);
        // stop voting with owner2
        vm.prank(address(owner2));
        voter.reset(address(owner2));

        // test multiple pools. only bribe pool1 with LR, pool2 with USDC
        // create normal bribes for pool1
        currentBribe = TOKEN_1 * 7;
        vm.startPrank(owner);
        _createBribeWithAmount(bribeVotingReward, address(LR), currentBribe);
        // create usdc bribe for pool2
        usdcBribe = USDC_1 * 7;
        _createBribeWithAmount(bribeVotingReward2, address(USDC), usdcBribe);
        vm.stopPrank();
        skip(1);

        // re-lock owner + owner3
        vm.prank(owner, owner);
        escrow.increase_unlock_time(MAXTIME + block.timestamp);
        vm.prank(address(owner3), owner3);
        escrow.increase_unlock_time(MAXTIME + block.timestamp);
        skip(1 hours);

        poolIds = new uint160[](2);
        weights = new uint256[](2);
        poolIds[0] = poolId1;
        poolIds[1] = poolId2;
        weights[0] = 2000;
        weights[1] = 8000;

        vm.prank(owner);
        voter.vote(address(owner), poolIds, weights); // 1 votes 20% pool1 80 pool2

        weights[0] = 8000;
        weights[1] = 2000;
        vm.prank(address(owner3));
        voter.vote(address(owner3), poolIds, weights); // 3 votes 80% pool1 20%% pool2

        skipToNextEpoch(1);

        // owner should receive 1/5, owner3 should receive 4/5 of pool1 bribes
        pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        post = LR.balanceOf(address(owner));
        assertApproxEqAbs(post - pre, currentBribe / 5, 3);

        pre = LR.balanceOf(address(owner3));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner3), rewards);
        post = LR.balanceOf(address(owner3));
        assertApproxEqAbs(post - pre, (currentBribe * 4) / 5, 3);

        // owner should receive 4/5, owner3 should receive 1/5 of pool2 bribes
        rewards[0] = address(USDC);
        delete rewards[1];
        usdcPre = USDC.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward2.getRewards(address(owner), rewards);
        usdcPost = USDC.balanceOf(address(owner));
        assertEq(usdcPost - usdcPre, (usdcBribe * 4) / 5);

        usdcPre = USDC.balanceOf(address(owner3));
        vm.prank(address(voter));
        bribeVotingReward2.getRewards(address(owner3), rewards);
        usdcPost = USDC.balanceOf(address(owner3));
        assertApproxEqAbs(usdcPost - usdcPre, usdcBribe / 5, 1);

        skipToNextEpoch(1);

        // test passive voting
        currentBribe = TOKEN_1 * 8;
        usdcBribe = USDC_1 * 8;
        vm.startPrank(owner);
        _createBribeWithAmount(bribeVotingReward, address(LR), currentBribe);
        _createBribeWithAmount(bribeVotingReward, address(USDC), usdcBribe);
        vm.stopPrank();
        skip(1 hours);

        poolIds = new uint160[](1);
        weights = new uint256[](1);
        poolIds[0] = poolId1;
        weights[0] = 500;
        rewards[0] = address(LR);
        rewards[1] = address(USDC);
        vm.prank(owner);
        voter.vote(address(owner), poolIds, weights);
        vm.prank(address(owner3));
        voter.vote(address(owner3), poolIds, weights);

        skipToNextEpoch(1);

        // check earned
        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, currentBribe / 2);
        earned = bribeVotingReward.earned(address(USDC), address(owner));
        assertEq(earned, usdcBribe / 2);
        earned = bribeVotingReward.earned(address(LR), address(owner3));
        assertEq(earned, currentBribe / 2);
        earned = bribeVotingReward.earned(address(USDC), address(owner3));
        assertEq(earned, usdcBribe / 2);

        currentBribe = TOKEN_1 * 9;
        usdcBribe = USDC_1 * 9;
        vm.startPrank(owner);
        _createBribeWithAmount(bribeVotingReward, address(LR), currentBribe);
        _createBribeWithAmount(bribeVotingReward, address(USDC), usdcBribe);
        vm.stopPrank();

        uint256 expected = (TOKEN_1 * 8) / 2;
        // check earned remains the same even if bribe gets re-deposited
        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, expected);
        earned = bribeVotingReward.earned(address(LR), address(owner3));
        assertEq(earned, expected);
        expected = (USDC_1 * 8) / 2;
        earned = bribeVotingReward.earned(address(USDC), address(owner));
        assertEq(earned, expected);
        earned = bribeVotingReward.earned(address(USDC), address(owner3));
        assertEq(earned, expected);

        skipToNextEpoch(1);

        currentBribe = TOKEN_1 * 10;
        usdcBribe = USDC_1 * 10;
        vm.startPrank(owner);
        _createBribeWithAmount(bribeVotingReward, address(LR), currentBribe);
        _createBribeWithAmount(bribeVotingReward, address(USDC), usdcBribe);
        vm.stopPrank();

        expected = (TOKEN_1 * 8 + TOKEN_1 * 9) / 2;
        earned = bribeVotingReward.earned(address(LR), address(owner));
        assertEq(earned, expected);
        earned = bribeVotingReward.earned(address(LR), address(owner3));
        assertEq(earned, expected);
        expected = (USDC_1 * 8 + USDC_1 * 9) / 2;
        earned = bribeVotingReward.earned(address(USDC), address(owner));
        assertEq(earned, expected);
        earned = bribeVotingReward.earned(address(USDC), address(owner3));
        assertEq(earned, expected);

        skipToNextEpoch(1);

        currentBribe = TOKEN_1 * 11;
        vm.startPrank(owner);
        _createBribeWithAmount(bribeVotingReward, address(LR), currentBribe);
        vm.stopPrank();

        pre = LR.balanceOf(address(owner));
        usdcPre = USDC.balanceOf(address(owner));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner), rewards);
        post = LR.balanceOf(address(owner));
        usdcPost = USDC.balanceOf(address(owner));
        expected = (TOKEN_1 * 8 + TOKEN_1 * 9 + TOKEN_1 * 10) / 2;
        assertEq(post - pre, expected);
        expected = (USDC_1 * 8 + USDC_1 * 9 + USDC_1 * 10) / 2;
        assertEq(usdcPost - usdcPre, expected);

        pre = LR.balanceOf(address(owner3));
        usdcPre = USDC.balanceOf(address(owner3));
        vm.prank(address(voter));
        bribeVotingReward.getRewards(address(owner3), rewards);
        post = LR.balanceOf(address(owner3));
        usdcPost = USDC.balanceOf(address(owner3));
        expected = (TOKEN_1 * 8 + TOKEN_1 * 9 + TOKEN_1 * 10) / 2;
        assertEq(post - pre, expected);
        expected = (USDC_1 * 8 + USDC_1 * 9 + USDC_1 * 10) / 2;
        assertEq(usdcPost - usdcPre, expected);
    }
}
