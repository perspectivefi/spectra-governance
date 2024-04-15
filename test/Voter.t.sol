// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "./BaseTest.sol";

contract VoterTest is BaseTest {
    event WhitelistBribeToken(address indexed whitelister, address indexed token, bool indexed _bool);
    event WhitelistUser(address indexed whitelister, address indexed user, bool indexed _bool);
    event Voted(
        address indexed voter,
        uint160 indexed poolId,
        address indexed user,
        uint256 weight,
        uint256 totalWeight,
        uint256 timestamp
    );
    event Abstained(
        address indexed voter,
        uint160 indexed poolId,
        address indexed user,
        uint256 weight,
        uint256 totalWeight,
        uint256 timestamp
    );
    event NotifyReward(address indexed sender, address indexed reward, uint256 amount);

    function testCannotInitializeWithoutGovernorRole() public {
        address[] memory testArr;

        vm.prank(address(owner2));
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, owner2));
        voter.initialize(testArr);
    }

    function testCannotSetMaxVotingNumWithoutGovernorRole() public {
        vm.prank(address(owner2));
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, owner2));
        voter.setMaxVotingNum(42);
    }

    function testCannotSetDaoFeesWithoutGovernorRole() public {
        vm.startPrank(address(owner2));
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, owner2));
        voter.setDefaultFeesRewardsDaoFee(100);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, owner2));
        voter.setDefaultBribeRewardsDaoFee(100);
    }

    function testCannotSetVRDaoFeesWithoutGovernorRole() public {
        uint160[] memory testArr1;
        address[] memory testArr2;

        vm.startPrank(address(owner2));
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, owner2));
        voter.setPoolsVotingRewardsDaoFee(testArr1, 0, 0);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, owner2));
        voter.setVotingRewardsDaoFee(testArr2, 0, testArr2, 0);
    }

    function testCannotSetRestrictedUserWithoutGovernorRole() public {
        vm.prank(address(owner2));
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, owner2));
        voter.setRestrictedUser(address(0), true);
    }

    function testCannotWhitelistWithoutGovernorRole() public {
        vm.prank(address(owner2));
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, owner2));
        voter.whitelistBribeToken(address(0), true);
    }

    function testCannotwhitelistUserWithoutGovernorRole() public {
        vm.prank(address(owner2));
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, owner2));
        voter.whitelistUser(address(owner), true);
    }

    function testCannotBanPoolWithoutEmergencyCouncilRole() public {
        vm.prank(address(owner2));
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, owner2));
        voter.banVote(poolId1);
    }

    function testCannotReauthorizePoolWithoutEmergencyCouncilRole() public {
        vm.prank(emergencyCouncil);
        voter.banVote(poolId1);

        vm.prank(address(owner2));
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, owner2));
        voter.reauthorizeVote(poolId1);
    }

    function testFactoryCannotCreateRewardsWithoutVoterRole() public {
        vm.prank(address(owner2));
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, owner2));
        votingRewardsFactory.createRewards(0, address(0), address(0), address(0), address(0), 0, 0);
    }

    // Note: _vote are not included in one-vote-per-epoch
    // Only vote() should be constrained as they must be called by the owner
    // Reset is not constrained as epochs are accrue and are distributed once per epoch
    // poke() can be called by anyone anytime to "refresh" an outdated vote state
    function testCannotChangeVoteInSameEpoch() public {
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);

        // vote
        skipToNextEpoch(1 hours + 1);
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;
        voter.vote(address(owner), poolIds, weights);

        // fwd half epoch
        skip(1 weeks / 2);

        // try voting again and fail
        poolIds[0] = poolId2;
        vm.expectRevert(IVoter.AlreadyVotedOrDeposited.selector);
        voter.vote(address(owner), poolIds, weights);
    }

    function testCannotResetUntilAfterDistributeWindow() public {
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);

        // vote
        skipToNextEpoch(1 hours + 1);
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;
        voter.vote(address(owner), poolIds, weights);

        skipToNextEpoch(0);
        vm.expectRevert(IVoter.DistributeWindow.selector);
        voter.reset(address(owner));

        skip(30 minutes);
        vm.expectRevert(IVoter.DistributeWindow.selector);
        voter.reset(address(owner));

        skip(30 minutes);
        vm.expectRevert(IVoter.DistributeWindow.selector);
        voter.reset(address(owner));

        skip(1);
        voter.reset(address(owner));
    }

    function testCannotResetInSameEpoch() public {
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);

        // vote
        skipToNextEpoch(1 hours + 1);
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;
        voter.vote(address(owner), poolIds, weights);

        // fwd half epoch
        skip(1 weeks / 2);

        // try resetting and fail
        vm.expectRevert(IVoter.AlreadyVotedOrDeposited.selector);
        voter.reset(address(owner));
    }

    function testCannotPokeUntilAfterDistributeWindow() public {
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);

        // vote
        skipToNextEpoch(1 hours + 1);
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;
        voter.vote(address(owner), poolIds, weights);

        skipToNextEpoch(0);
        vm.expectRevert(IVoter.DistributeWindow.selector);
        voter.poke(address(owner));

        skip(30 minutes);
        vm.expectRevert(IVoter.DistributeWindow.selector);
        voter.poke(address(owner));

        skip(30 minutes);
        vm.expectRevert(IVoter.DistributeWindow.selector);
        voter.poke(address(owner));

        skip(1);
        voter.poke(address(owner));
    }

    function testPoke() public {
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);
        skipAndRoll(1 hours);

        voter.poke(address(owner));

        assertFalse(voter.voted(address(owner)));
        assertEq(voter.lastVoted(address(owner)), 0);
        assertEq(voter.totalWeight(), 0);
        assertEq(voter.usedWeights(address(owner)), 0);
    }

    function testPokeAfterVote() public {
        skip(1 hours + 1);
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);

        // vote
        uint160[] memory poolIds = new uint160[](2);
        poolIds[0] = poolId1;
        poolIds[1] = poolId2;
        uint256[] memory weights = new uint256[](2);
        weights[0] = 1;
        weights[1] = 2;

        /// balance: 997203164581747618
        vm.expectEmit(true, false, false, true, address(voter));
        emit Voted(address(owner), poolId1, address(owner), 332401054860582539, 332401054860582539, block.timestamp);
        vm.expectEmit(true, false, false, true, address(voter));
        emit Voted(address(owner), poolId2, address(owner), 664802109721165078, 664802109721165078, block.timestamp);
        voter.vote(address(owner), poolIds, weights);

        assertTrue(voter.voted(address(owner)));
        assertEq(voter.lastVoted(address(owner)), block.timestamp);
        assertEq(voter.totalWeight(), 997203164581747617);
        assertEq(voter.usedWeights(address(owner)), 997203164581747617);
        assertEq(voter.weights(poolId1), 332401054860582539);
        assertEq(voter.weights(poolId2), 664802109721165078);
        assertEq(voter.votes(address(owner), poolId1), 332401054860582539);
        assertEq(voter.votes(address(owner), poolId2), 664802109721165078);
        assertEq(voter.poolVote(address(owner), 0), poolId1);
        assertEq(voter.poolVote(address(owner), 1), poolId2);

        vm.expectEmit(true, false, false, true, address(voter));
        emit Voted(address(owner), poolId1, address(owner), 332401054860582539, 332401054860582539, block.timestamp);
        vm.expectEmit(true, false, false, true, address(voter));
        emit Voted(address(owner), poolId2, address(owner), 664802109721165078, 664802109721165078, block.timestamp);
        voter.poke(address(owner));
        uint256 timestamp = block.timestamp;

        assertTrue(voter.voted(address(owner)));
        assertEq(voter.lastVoted(address(owner)), block.timestamp);
        assertEq(voter.totalWeight(), 997203164581747617);
        assertEq(voter.usedWeights(address(owner)), 997203164581747617);
        assertEq(voter.weights(poolId1), 332401054860582539);
        assertEq(voter.weights(poolId2), 664802109721165078);
        assertEq(voter.votes(address(owner), poolId1), 332401054860582539);
        assertEq(voter.votes(address(owner), poolId2), 664802109721165078);
        assertEq(voter.poolVote(address(owner), 0), poolId1);
        assertEq(voter.poolVote(address(owner), 1), poolId2);

        skipAndRoll(1 days);
        // balance: 995833301568125218
        vm.expectEmit(true, false, false, true, address(voter));
        emit Voted(address(owner), poolId1, address(owner), 331944433856041739, 331944433856041739, block.timestamp);
        vm.expectEmit(true, false, false, true, address(voter));
        emit Voted(address(owner), poolId2, address(owner), 663888867712083478, 663888867712083478, block.timestamp);
        voter.poke(address(owner));

        assertTrue(voter.voted(address(owner)));
        assertEq(voter.lastVoted(address(owner)), timestamp);
        assertEq(voter.totalWeight(), 995833301568125217);
        assertEq(voter.usedWeights(address(owner)), 995833301568125217);
        assertEq(voter.weights(poolId1), 331944433856041739);
        assertEq(voter.weights(poolId2), 663888867712083478);
        assertEq(voter.votes(address(owner), poolId1), 331944433856041739);
        assertEq(voter.votes(address(owner), poolId2), 663888867712083478);
        assertEq(voter.poolVote(address(owner), 0), poolId1);
        assertEq(voter.poolVote(address(owner), 1), poolId2);
    }

    function testVoteAfterResetInSameEpoch() public {
        skip(1 weeks / 2);
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);

        // create a bribe
        LR.approve(address(bribeVotingReward), TOKEN_1);
        bribeVotingReward.notifyRewardAmount(address(LR), TOKEN_1);
        // vote
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 1;
        voter.vote(address(owner), poolIds, weights);

        skipToNextEpoch(1 hours + 1);

        assertEq(bribeVotingReward.earned(address(LR), address(owner)), TOKEN_1);

        voter.reset(address(owner));

        skip(1 days);

        LR.approve(address(bribeVotingReward2), TOKEN_1);
        bribeVotingReward2.notifyRewardAmount(address(LR), TOKEN_1);
        poolIds[0] = poolId2;
        voter.vote(address(owner), poolIds, weights);

        skipToNextEpoch(1);

        // rewards only occur for pool2, not pool1
        assertEq(bribeVotingReward.earned(address(LR), address(owner)), TOKEN_1);
        assertEq(bribeVotingReward2.earned(address(LR), address(owner)), TOKEN_1);
    }

    function testVote() public {
        skip(1 hours + 1);
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);

        // vote
        uint160[] memory poolIds = new uint160[](2);
        poolIds[0] = poolId1;
        poolIds[1] = poolId2;
        uint256[] memory weights = new uint256[](2);
        weights[0] = 1;
        weights[1] = 2;

        /// balance: 997203164581747618
        vm.expectEmit(true, true, false, true, address(voter));
        emit Voted(address(owner), poolId1, address(owner), 332401054860582539, 332401054860582539, block.timestamp);
        vm.expectEmit(true, true, false, true, address(voter));
        emit Voted(address(owner), poolId2, address(owner), 664802109721165078, 664802109721165078, block.timestamp);
        voter.vote(address(owner), poolIds, weights);

        assertTrue(voter.voted(address(owner)));
        assertEq(voter.lastVoted(address(owner)), block.timestamp);
        assertEq(voter.totalWeight(), 997203164581747617);
        assertEq(voter.usedWeights(address(owner)), 997203164581747617);
        assertEq(voter.weights(poolId1), 332401054860582539);
        assertEq(voter.weights(poolId2), 664802109721165078);
        assertEq(voter.votes(address(owner), poolId1), 332401054860582539);
        assertEq(voter.votes(address(owner), poolId2), 664802109721165078);
        assertEq(voter.poolVote(address(owner), 0), poolId1);
        assertEq(voter.poolVote(address(owner), 1), poolId2);

        vm.startPrank(address(owner2), address(owner2));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);
        vm.expectEmit(true, true, false, true, address(voter));
        emit Voted(address(owner2), poolId1, address(owner2), 332401054860582539, 664802109721165078, block.timestamp);
        vm.expectEmit(true, true, false, true, address(voter));
        emit Voted(address(owner2), poolId2, address(owner2), 664802109721165078, 1329604219442330156, block.timestamp);
        voter.vote(address(owner2), poolIds, weights);
        vm.stopPrank();

        assertTrue(voter.voted(address(owner)));
        assertEq(voter.lastVoted(address(owner)), block.timestamp);
        assertEq(voter.totalWeight(), 1994406329163495234);
        assertEq(voter.usedWeights(address(owner)), 997203164581747617);
        assertEq(voter.weights(poolId1), 664802109721165078);
        assertEq(voter.weights(poolId2), 1329604219442330156);
        assertEq(voter.votes(address(owner), poolId1), 332401054860582539);
        assertEq(voter.votes(address(owner), poolId2), 664802109721165078);
        assertEq(voter.poolVote(address(owner), 0), poolId1);
        assertEq(voter.poolVote(address(owner), 1), poolId2);
    }

    function testBatchVoteAndPoke() public {
        skip(1 hours + 1);

        address[] memory owners = new address[](3);
        owners[0] = owner;
        owners[1] = owner2;
        owners[2] = owner3;

        for (uint i; i < owners.length; i++) {
            vm.startPrank(address(owners[i]), address(owners[i]));
            APW.approve(address(escrow), TOKEN_1);
            escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);
            voter.setApprovalForAll(address(this), true);
            vm.stopPrank();
        }

        // vote
        uint160[] memory poolIds = new uint160[](2);
        poolIds[0] = poolId1;
        poolIds[1] = poolId2;
        uint256[] memory weights = new uint256[](2);
        weights[0] = 1;
        weights[1] = 2;

        for (uint256 i; i < owners.length; i++) {
            /// balance: 997203164581747618
            vm.expectEmit(true, false, false, true, address(voter));
            emit Voted(
                address(this),
                poolId1,
                address(owners[i]),
                332401054860582539,
                332401054860582539 * (i + 1),
                block.timestamp
            );
            vm.expectEmit(true, false, false, true, address(voter));
            emit Voted(
                address(this),
                poolId2,
                address(owners[i]),
                664802109721165078,
                664802109721165078 * (i + 1),
                block.timestamp
            );
        }
        voter.batchVote(owners, poolIds, weights);

        assertEq(voter.totalWeight(), 997203164581747617 * owners.length);
        assertEq(voter.weights(poolId1), 332401054860582539 * owners.length);
        assertEq(voter.weights(poolId2), 664802109721165078 * owners.length);
        for (uint256 i; i < owners.length; i++) {
            assertTrue(voter.voted(address(owners[i])));
            assertEq(voter.lastVoted(address(owners[i])), block.timestamp);
            assertEq(voter.usedWeights(address(owners[i])), 997203164581747617);
            assertEq(voter.votes(address(owners[i]), poolId1), 332401054860582539);
            assertEq(voter.votes(address(owners[i]), poolId2), 664802109721165078);
            assertEq(voter.poolVote(address(owners[i]), 0), poolId1);
            assertEq(voter.poolVote(address(owners[i]), 1), poolId2);
        }

        for (uint256 i; i < owners.length; i++) {
            vm.expectEmit(true, false, false, true, address(voter));
            emit Voted(
                address(this),
                poolId1,
                address(owners[i]),
                332401054860582539,
                332401054860582539 * owners.length,
                block.timestamp
            );
            vm.expectEmit(true, false, false, true, address(voter));
            emit Voted(
                address(this),
                poolId2,
                address(owners[i]),
                664802109721165078,
                664802109721165078 * owners.length,
                block.timestamp
            );
        }
        voter.batchPoke(owners);

        uint256 timestamp = block.timestamp;

        assertEq(voter.totalWeight(), 997203164581747617 * owners.length);
        assertEq(voter.weights(poolId1), 332401054860582539 * owners.length);
        assertEq(voter.weights(poolId2), 664802109721165078 * owners.length);
        for (uint256 i; i < owners.length; i++) {
            assertTrue(voter.voted(address(owners[i])));
            assertEq(voter.lastVoted(address(owners[i])), block.timestamp);
            assertEq(voter.usedWeights(address(owners[i])), 997203164581747617);
            assertEq(voter.votes(address(owners[i]), poolId1), 332401054860582539);
            assertEq(voter.votes(address(owners[i]), poolId2), 664802109721165078);
            assertEq(voter.poolVote(address(owners[i]), 0), poolId1);
            assertEq(voter.poolVote(address(owners[i]), 1), poolId2);
        }

        skipAndRoll(1 days);
        for (uint256 i; i < owners.length; i++) {
            // balance: 995833301568125218
            vm.expectEmit(true, false, false, true, address(voter));
            emit Voted(
                address(this),
                poolId1,
                address(owner),
                331944433856041739,
                (332401054860582539 * (owners.length - (i + 1))) + (331944433856041739 * (i + 1)),
                block.timestamp
            );
            vm.expectEmit(true, false, false, true, address(voter));
            emit Voted(
                address(this),
                poolId2,
                address(owner),
                663888867712083478,
                (664802109721165078 * (owners.length - (i + 1))) + (663888867712083478 * (i + 1)),
                block.timestamp
            );
        }
        voter.batchPoke(owners);

        assertEq(voter.totalWeight(), 995833301568125217 * owners.length);
        assertEq(voter.weights(poolId1), 331944433856041739 * owners.length);
        assertEq(voter.weights(poolId2), 663888867712083478 * owners.length);
        for (uint256 i; i < owners.length; i++) {
            assertTrue(voter.voted(address(owners[i])));
            assertEq(voter.lastVoted(address(owners[i])), timestamp);
            assertEq(voter.usedWeights(address(owners[i])), 995833301568125217);
            assertEq(voter.votes(address(owners[i]), poolId1), 331944433856041739);
            assertEq(voter.votes(address(owners[i]), poolId2), 663888867712083478);
            assertEq(voter.poolVote(address(owners[i]), 0), poolId1);
            assertEq(voter.poolVote(address(owners[i]), 1), poolId2);
        }
    }

    function testReset() public {
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);
        skipAndRoll(1 hours + 1);

        voter.reset(address(owner));

        assertFalse(voter.voted(address(owner)));
        assertEq(voter.totalWeight(), 0);
        assertEq(voter.usedWeights(address(owner)), 0);
        vm.expectRevert();
        voter.poolVote(address(owner), 0);
    }

    function testResetAfterVote() public {
        skipAndRoll(1 hours + 1);
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);

        vm.startPrank(address(owner2), address(owner2));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);
        vm.stopPrank();

        // vote
        uint160[] memory poolIds = new uint160[](2);
        poolIds[0] = poolId1;
        poolIds[1] = poolId2;
        uint256[] memory weights = new uint256[](2);
        weights[0] = 1;
        weights[1] = 2;

        //total balance of owner and owner2: 997203164581747618
        vm.expectEmit(true, true, false, true, address(voter));
        emit Voted(address(owner), poolId1, address(owner), 332401054860582539, 332401054860582539, block.timestamp);
        vm.expectEmit(true, true, false, true, address(voter));
        emit Voted(address(owner), poolId2, address(owner), 664802109721165078, 664802109721165078, block.timestamp);
        vm.prank(owner);
        voter.vote(address(owner), poolIds, weights);
        vm.prank(address(owner2), address(owner2));
        vm.expectEmit(true, true, false, true, address(voter));
        emit Voted(address(owner2), poolId1, address(owner2), 332401054860582539, 664802109721165078, block.timestamp);
        vm.expectEmit(true, true, false, true, address(voter));
        emit Voted(address(owner2), poolId2, address(owner2), 664802109721165078, 1329604219442330156, block.timestamp);
        voter.vote(address(owner2), poolIds, weights);

        assertEq(voter.totalWeight(), 1994406329163495234);
        assertEq(voter.usedWeights(address(owner)), 997203164581747617);
        assertEq(voter.weights(poolId1), 664802109721165078);
        assertEq(voter.weights(poolId2), 1329604219442330156);
        assertEq(voter.votes(address(owner), poolId1), 332401054860582539);
        assertEq(voter.votes(address(owner), poolId2), 664802109721165078);
        assertEq(voter.poolVote(address(owner), 0), poolId1);
        assertEq(voter.poolVote(address(owner), 1), poolId2);

        uint256 lastVoted = voter.lastVoted(address(owner));
        skipToNextEpoch(1 hours + 1);
        vm.prank(owner);
        vm.expectEmit(true, true, false, true, address(voter));
        emit Abstained(address(owner), poolId1, owner, 332401054860582539, 332401054860582539, block.timestamp);
        vm.expectEmit(true, true, false, true, address(voter));
        emit Abstained(address(owner), poolId2, owner, 664802109721165078, 664802109721165078, block.timestamp);
        voter.reset(address(owner));

        assertFalse(voter.voted(address(owner)));
        assertEq(voter.lastVoted(address(owner)), lastVoted);
        assertEq(voter.totalWeight(), 997203164581747617);
        assertEq(voter.usedWeights(address(owner)), 0);
        assertEq(voter.weights(poolId1), 332401054860582539);
        assertEq(voter.weights(poolId2), 664802109721165078);
        assertEq(voter.votes(address(owner), poolId1), 0);
        assertEq(voter.votes(address(owner), poolId2), 0);
        vm.expectRevert();
        voter.poolVote(address(owner), 0);
    }

    function testResetAfterVoteOnBannedPool() public {
        skipAndRoll(1 hours + 1);
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);

        // vote
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;
        voter.vote(address(owner), poolIds, weights);

        // ban vote for voted pool
        vm.startPrank(emergencyCouncil);
        voter.banVote(poolId1);
        vm.stopPrank();

        // skip to the next epoch to be able to reset - no revert
        skipToNextEpoch(1 hours + 1);
        vm.prank(owner);
        voter.reset(address(owner));
    }

    function testCannotVoteUntilAnHourAfterEpochFlips() public {
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);

        // vote
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;

        skipToNextEpoch(0);
        vm.expectRevert(IVoter.DistributeWindow.selector);
        voter.vote(address(owner), poolIds, weights);

        skip(30 minutes);
        vm.expectRevert(IVoter.DistributeWindow.selector);
        voter.vote(address(owner), poolIds, weights);

        skip(30 minutes);
        vm.expectRevert(IVoter.DistributeWindow.selector);
        voter.vote(address(owner), poolIds, weights);

        skip(1);
        voter.vote(address(owner), poolIds, weights);
    }

    function testCannotVoteAnHourBeforeEpochFlips() public {
        skipToNextEpoch(0);
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);

        // vote
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;

        skip(7 days - 1 hours);
        uint256 sid = vm.snapshot();
        voter.vote(address(owner), poolIds, weights);

        vm.revertTo(sid);
        skip(1);
        vm.expectRevert(IVoter.NotWhitelistedUser.selector);
        voter.vote(address(owner), poolIds, weights);

        skip(1 hours - 2); /// one second prior to epoch flip
        vm.expectRevert(IVoter.NotWhitelistedUser.selector);
        voter.vote(address(owner), poolIds, weights);

        vm.startPrank(dao);
        voter.whitelistUser((address(owner)), true);

        vm.startPrank(address(owner));
        voter.vote(address(owner), poolIds, weights);

        skipToNextEpoch(1 hours + 1); /// new epoch
        voter.vote(address(owner), poolIds, weights);
    }

    function testCannotVoteForBannedPool() public {
        skipToNextEpoch(60 minutes + 1);

        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);
        vm.stopPrank();

        // vote
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;

        // ban the pool voted for
        vm.prank(emergencyCouncil);
        voter.banVote(poolId1);
        vm.startPrank(owner);
        vm.expectRevert(IVoter.VoteUnauthorized.selector);
        voter.vote(address(owner), poolIds, weights);
    }

    function testCannotVoteIfUserIsRestricted() public {
        skipToNextEpoch(60 minutes + 1);

        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);
        vm.stopPrank();

        // vote
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;

        // restrict user from voting
        vm.prank(dao);
        voter.setRestrictedUser(owner, true);
        vm.startPrank(owner);
        vm.expectRevert(IVoter.UserRestricted.selector);
        voter.vote(address(owner), poolIds, weights);
    }

    function testCannotCreateVotingRewardsIfAlreadyExists() public {
        assertTrue(voter.hasVotingRewards(poolId1));
        assertEq(voter.poolToFees(poolId1), address(feesVotingReward));
        assertEq(voter.poolToBribe(poolId1), address(bribeVotingReward));
        vm.expectRevert(IVoter.VotingRewardsAlreadyDeployed.selector);
        voter.createVotingRewards(poolId1);
    }

    function testCannotCreateVotingRewardsForUnregisteredPool() public {
        vm.expectRevert(IVoter.NotARegisteredPool.selector);
        voter.createVotingRewards(1234);
    }

    function testGetAllPoolIds() public {
        address _pool = makeAddr("New Pool");
        uint256 _chainId = 123;
        uint160 _poolId = governanceRegistry.getPoolId(_pool, _chainId);
        governanceRegistry.setPoolRegistration(_pool, _chainId, true);

        uint160[] memory _poolIds = voter.getAllPoolIds();
        assertEq(_poolIds.length, 3);
        assertEq(_poolIds[0], poolId1);
        assertEq(_poolIds[1], poolId2);
        assertEq(_poolIds[2], poolId3);

        voter.createVotingRewards(_poolId);

        _poolIds = voter.getAllPoolIds();
        assertEq(_poolIds.length, 4);
        assertEq(_poolIds[0], poolId1);
        assertEq(_poolIds[1], poolId2);
        assertEq(_poolIds[2], poolId3);
        assertEq(_poolIds[3], _poolId);
    }

    function testCannotVoteForPoolWithoutVotingRewards() public {
        skipToNextEpoch(60 minutes + 1);

        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);

        // vote
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = 1234;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;

        vm.expectRevert(IVoter.VotingRewardsNotDeployed.selector);
        voter.vote(address(owner), poolIds, weights);
    }

    function testCannotSetMaxVotingNumToSameNum() public {
        uint256 maxVotingNum = voter.maxVotingNum();
        vm.prank(dao);
        vm.expectRevert(IVoter.SameValue.selector);
        voter.setMaxVotingNum(maxVotingNum);
    }

    function testCannotSetMaxVotingNumBelow10() public {
        vm.startPrank(dao);
        vm.expectRevert(IVoter.MaximumVotingNumberTooLow.selector);
        voter.setMaxVotingNum(9);
    }

    function testSetMaxVotingNum() public {
        assertEq(voter.maxVotingNum(), 30);
        vm.prank(dao);
        voter.setMaxVotingNum(10);
        assertEq(voter.maxVotingNum(), 10);
    }

    function testCannotSetDaoFeeWithInvalidFee() public {
        vm.startPrank(dao);

        vm.expectRevert(IVoter.FeeTooHigh.selector);
        voter.setDefaultFeesRewardsDaoFee(10001);

        vm.expectRevert(IVoter.FeeTooHigh.selector);
        voter.setDefaultBribeRewardsDaoFee(10001);
    }

    function testCannotSetDaoFeeForMultiplePoolsWithPoolWithoutVotingRewards() public {
        uint160[] memory poolIds = new uint160[](2);
        poolIds[0] = poolId1;
        poolIds[1] = 1234;

        vm.startPrank(dao);
        vm.expectRevert(IVoter.VotingRewardsNotDeployed.selector);
        voter.setPoolsVotingRewardsDaoFee(poolIds, 100, 100);
    }

    function testSetDaoFeeForMultiplePools() public {
        uint160[] memory poolIds = new uint160[](2);
        poolIds[0] = poolId1;
        poolIds[1] = poolId3;

        vm.startPrank(dao);
        voter.setPoolsVotingRewardsDaoFee(poolIds, 150, 20);

        assertEq(feesVotingReward.daoFee(), 150);
        assertEq(feesVotingReward2.daoFee(), 0);
        assertEq(feesVotingReward3.daoFee(), 150);

        assertEq(bribeVotingReward.daoFee(), 20);
        assertEq(bribeVotingReward2.daoFee(), 0);
        assertEq(bribeVotingReward3.daoFee(), 20);
    }

    function testSetDaoFeeForMultipleRewards() public {
        address[] memory fees = new address[](2);
        fees[0] = address(feesVotingReward);
        fees[1] = address(feesVotingReward2);

        address[] memory bribes = new address[](2);
        bribes[0] = address(bribeVotingReward);
        bribes[1] = address(bribeVotingReward2);

        vm.startPrank(dao);
        voter.setVotingRewardsDaoFee(fees, 150, bribes, 20);

        assertEq(feesVotingReward.daoFee(), 150);
        assertEq(feesVotingReward2.daoFee(), 150);

        assertEq(bribeVotingReward.daoFee(), 20);
        assertEq(bribeVotingReward2.daoFee(), 20);
    }

    function testWhitelistBribeTokenWithTrueExpectWhitelisted() public {
        address token = address(new MockERC20("TEST", "TEST", 18));

        assertFalse(voter.isWhitelistedBribeToken(token));

        vm.startPrank(dao);
        vm.expectEmit(true, true, true, true, address(voter));
        emit WhitelistBribeToken(dao, address(token), true);
        voter.whitelistBribeToken(token, true);

        assertTrue(voter.isWhitelistedBribeToken(token));
    }

    function testWhitelistBribeTokenWithFalseExpectUnwhitelisted() public {
        address token = address(new MockERC20("TEST", "TEST", 18));

        assertFalse(voter.isWhitelistedBribeToken(token));

        vm.prank(dao);
        voter.whitelistBribeToken(token, true);

        assertTrue(voter.isWhitelistedBribeToken(token));

        vm.startPrank(dao);
        vm.expectEmit(true, true, true, true, address(voter));
        emit WhitelistBribeToken(dao, address(token), false);
        voter.whitelistBribeToken(token, false);

        assertFalse(voter.isWhitelistedBribeToken(token));
    }

    function testwhitelistUserWithTrueExpectWhitelisted() public {
        assertFalse(voter.isWhitelistedUser(address(owner)));

        vm.startPrank(dao);
        vm.expectEmit(true, true, true, true, address(voter));
        emit WhitelistUser(dao, address(owner), true);
        voter.whitelistUser(address(owner), true);

        assertTrue(voter.isWhitelistedUser(address(owner)));
    }

    function testwhitelistUserWithFalseExpectUnwhitelisted() public {
        assertFalse(voter.isWhitelistedUser(address(owner)));

        vm.prank(dao);
        voter.whitelistUser(address(owner), true);

        assertTrue(voter.isWhitelistedUser(address(owner)));

        vm.startPrank(dao);
        vm.expectEmit(true, true, true, true, address(voter));
        emit WhitelistUser(dao, address(owner), false);
        voter.whitelistUser(address(owner), false);

        assertFalse(voter.isWhitelistedUser(address(owner)));
    }

    function testBanPool() public {
        assertTrue(voter.isVoteAuthorized(poolId1));
        vm.startPrank(emergencyCouncil);
        voter.banVote(poolId1);
        assertFalse(voter.isVoteAuthorized(poolId1));
    }

    function testCannotBanPoolIfAlreadyBanned() public {
        vm.startPrank(emergencyCouncil);
        voter.banVote(poolId1);
        assertFalse(voter.isVoteAuthorized(poolId1));

        vm.expectRevert(IVoter.VoteAlreadyBanned.selector);
        voter.banVote(poolId1);
    }

    function testReauthorizePool() public {
        vm.startPrank(emergencyCouncil);
        voter.banVote(poolId1);
        assertFalse(voter.isVoteAuthorized(poolId1));

        voter.reauthorizeVote(poolId1);
        assertTrue(voter.isVoteAuthorized(poolId1));
    }

    function testCannotReauthorizePoolIfAlreadyAuthorized() public {
        assertTrue(voter.isVoteAuthorized(poolId1));

        vm.prank(emergencyCouncil);
        vm.expectRevert(IVoter.VoteAlreadyAuthorized.selector);
        voter.reauthorizeVote(poolId1);
    }

    function testCannotBanPoolWithoutVotingRewards() public {
        vm.prank(emergencyCouncil);
        vm.expectRevert(IVoter.VotingRewardsNotDeployed.selector);
        voter.banVote(1234);
    }

    function testSetRestrictedUser() public {
        assertFalse(voter.isRestrictedUser(owner));
        vm.startPrank(dao);
        voter.setRestrictedUser(owner, true);
        assertTrue(voter.isRestrictedUser(owner));
        voter.setRestrictedUser(owner, false);
        assertFalse(voter.isRestrictedUser(owner));
    }

    function _seedVoterWithVotingSupply() internal {
        skip(1 hours + 1);
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);
        skip(1);

        uint160[] memory poolIds = new uint160[](2);
        poolIds[0] = poolId1;
        poolIds[1] = poolId2;
        uint256[] memory weights = new uint256[](2);
        weights[0] = 1;
        weights[1] = 1;
        voter.vote(address(owner), poolIds, weights);
        vm.stopPrank();
    }
}
