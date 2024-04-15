// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "./BaseTest.sol";

contract FullCycleTest is BaseTest {
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    bytes4[] private voting_rewards_factory_methods_selectors = new bytes4[](1);

    constructor() {
        deploymentType = Deployment.CUSTOM;
    }

    function _setUp() public override {
        skip(1 weeks);

        escrow = IVotingEscrow(0xC5ca1EBF6e912E49A6a70Bb0385Ea065061a4F09);
        dao = makeAddr("SpectraDAO");
        feesVotingRewardsDistributor = makeAddr("FeesVotingRewardsDistributor");

        deployAccessManager();

        pool1 = makeAddr("Pool1");
        pool2 = makeAddr("Pool2");
        pool3 = makeAddr("Pool3");

        uint256 chainId1 = 1;
        uint256 chainId2 = 2;
        uint256 chainId3 = 3;

        address[] memory poolsAddr = new address[](3);
        uint256[] memory poolsChainId = new uint256[](3);

        poolsAddr[0] = pool1;
        poolsAddr[1] = pool2;
        poolsAddr[2] = pool3;

        poolsChainId[0] = chainId1;
        poolsChainId[1] = chainId2;
        poolsChainId[2] = chainId3;

        // deploy owners and coins
        deployOwners();
        deployCoins();
        mintStables();

        // deal coins to owner
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = TOKEN_10M;
        amounts[1] = TOKEN_10M;
        amounts[2] = TOKEN_10M;
        mintToken(address(APW), owners, amounts);

        // deal ETH to feesVotingRewardsDistributor
        vm.deal(feesVotingRewardsDistributor, 10 ether);

        tokens = new address[](4);
        tokens[0] = address(USDC);
        tokens[1] = address(FRAX);
        tokens[2] = address(DAI);
        tokens[3] = address(APW);

        votingRewardsFactory = new VotingRewardsFactory(address(accessManager));
        voting_rewards_factory_methods_selectors[0] = IVotingRewardsFactory(address(0)).createRewards.selector;
        accessManager.setTargetFunctionRole(
            address(votingRewardsFactory),
            voting_rewards_factory_methods_selectors,
            Roles.VOTER_ROLE
        );
        accessManager.grantRole(Roles.ADMIN_ROLE, address(votingRewardsFactory), 0);

        governanceRegistry = new GovernanceRegistry(address(accessManager));
        governanceRegistry.setVotingRewardsFactory(address(votingRewardsFactory));
        governanceRegistry.setPoolsRegistration(poolsAddr, poolsChainId, true);

        poolId1 = governanceRegistry.getPoolId(pool1, chainId1);
        poolId2 = governanceRegistry.getPoolId(pool2, chainId2);
        poolId3 = governanceRegistry.getPoolId(pool3, chainId3);

        voter = new Voter(
            dao,
            address(accessManager),
            address(forwarder),
            address(escrow),
            address(governanceRegistry),
            100,
            0
        );
        accessManager.grantRole(Roles.VOTER_ROLE, address(voter), 0);
        assertEq(voter.length(), 0);
        voter.initialize(tokens);
    }

    function _createLock(address _user, uint256 _amount) internal {
        uint256 pre = APW.balanceOf(address(escrow));

        vm.startPrank(_user, _user);
        APW.approve(address(escrow), _amount);
        escrow.create_lock(_amount, MAXTIME + block.timestamp);
        vm.stopPrank();

        uint256 post = APW.balanceOf(address(escrow));
        assertEq(post - pre, _amount);
    }

    function _deployVotingRewards() internal {
        voter.createVotingRewards(poolId2);
        voter.createVotingRewards(poolId3);
        assertTrue(voter.hasVotingRewards(poolId3));
        assertNotEq(voter.poolToFees(poolId3), address(0));
        assertNotEq(voter.poolToBribe(poolId3), address(0));

        feesVotingReward2 = FeesVotingReward(voter.poolToFees(poolId2));
        feesVotingReward3 = FeesVotingReward(voter.poolToFees(poolId3));
    }

    function _voterReset(address _user) internal {
        skip(1 hours);
        vm.prank(_user);
        voter.reset(_user);
    }

    function _voterPokeSelf(address _user) internal {
        vm.prank(_user);
        voter.poke(_user);
    }

    function _voterVoteAndCheckFeesVRBalanceOf(
        address _user,
        uint160[] memory _poolIds,
        uint256[] memory _weights
    ) internal {
        vm.prank(_user);
        voter.vote(_user, _poolIds, _weights);
        assertGt(voter.totalWeight(), 0);
        for (uint256 i; i > _poolIds.length; i++) {
            assertGt(IVotingReward(voter.poolToFees(_poolIds[i])).balanceOf(_user), 0);
        }
    }

    function _distributeETHFeesRewards() internal {
        vm.startPrank(feesVotingRewardsDistributor);
        feesVotingReward2.notifyRewardAmountETH{value: 1 ether}();
        feesVotingReward3.notifyRewardAmountETH{value: 2 ether}();
        vm.stopPrank();
    }

    function _feesVotingRewardClaimRewards(address _user, uint160 _poolId) internal returns (uint256 earnedETH) {
        address[] memory tokens = new address[](1);
        tokens[0] = ETH;

        address _feesVotingReward = voter.poolToFees(_poolId);

        earnedETH = IVotingReward(_feesVotingReward).earned(ETH, _user);

        uint256 preETH = _user.balance;
        vm.prank(_user);
        IVotingReward(_feesVotingReward).getRewards(_user, tokens);
        uint256 postETH = _user.balance;

        assertEq(postETH - preETH, earnedETH);
    }

    function testFullCycle() public {
        skipToNextEpoch(1);
        console2.log("------ epoch 1 ------");

        _createLock(owner, TOKEN_1M);
        _createLock(owner2, TOKEN_1M / 2);
        _createLock(owner3, TOKEN_1M);

        assertEq(escrow.balanceOf(address(owner)), 997260258117706731983307);
        // ve balance is not exactly linear to deposited amount
        assertApproxEqRel(escrow.balanceOf(address(owner2)), escrow.balanceOf(address(owner)) / 2, 1e2);
        assertEq(escrow.balanceOf(address(owner3)), escrow.balanceOf(address(owner)));

        _deployVotingRewards();

        uint160[] memory poolIds = new uint160[](2);
        poolIds[0] = poolId2;
        poolIds[1] = poolId3;
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5000;
        weights[1] = 10000;

        _voterReset(owner);
        _voterPokeSelf(owner);
        _voterVoteAndCheckFeesVRBalanceOf(owner, poolIds, weights);

        _voterVoteAndCheckFeesVRBalanceOf(owner2, poolIds, weights);

        weights[0] = 10000;
        weights[1] = 5000;
        _voterVoteAndCheckFeesVRBalanceOf(owner3, poolIds, weights);

        _distributeETHFeesRewards();

        skipToNextEpoch(1 days);
        console2.log("------ epoch 2 ------");

        uint256 earnedETH_1_3 = _feesVotingRewardClaimRewards(owner, poolId3);
        console2.log("owner1 ETH voting rewards for pool3 :", earnedETH_1_3);

        uint256 earnedETH_2_3 = _feesVotingRewardClaimRewards(owner2, poolId3);
        console2.log("owner2 ETH voting rewards for pool3 :", earnedETH_2_3);

        uint256 earnedETH_3_3 = _feesVotingRewardClaimRewards(owner3, poolId3);
        console2.log("owner3 ETH voting rewards for pool3 :", earnedETH_3_3);

        assertApproxEqRel(earnedETH_1_3 / 2, earnedETH_2_3, 1e2);
        assertEq(earnedETH_1_3 / 2, earnedETH_3_3);

        _distributeETHFeesRewards();

        skipToNextEpoch(1 days);
        console2.log("------ epoch 3 ------");

        earnedETH_1_3 = _feesVotingRewardClaimRewards(owner, poolId3);
        console2.log("owner1 ETH voting rewards for pool3 :", earnedETH_1_3);

        earnedETH_2_3 = _feesVotingRewardClaimRewards(owner2, poolId3);
        console2.log("owner2 ETH voting rewards for pool3 :", earnedETH_2_3);

        earnedETH_3_3 = _feesVotingRewardClaimRewards(owner3, poolId3);
        console2.log("owner3 ETH voting rewards for pool3 :", earnedETH_3_3);
    }
}
