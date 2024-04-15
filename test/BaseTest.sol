// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "./Base.sol";
import {MockERC20} from "utils/MockERC20.sol";

abstract contract BaseTest is Base {
    uint256 constant USDC_1 = 1e6;
    uint256 constant USDC_10K = 1e10; // 1e4 = 10K tokens with 6 decimals
    uint256 constant USDC_100K = 1e11; // 1e5 = 100K tokens with 6 decimals
    uint256 constant USDC_1M = 1e12; // 1e6 = 100K tokens with 6 decimals
    uint256 constant USDC_10M = 1e13; // 1e7 = 10M tokens with 6 decimals
    uint256 constant USDC_100M = 1e14; // 1e8 = 100M tokens with 6 decimals
    uint256 constant USDC_10B = 1e16; // 1e10 = 10B tokens with 6 decimals
    uint256 constant TOKEN_1 = 1e18;
    uint256 constant TOKEN_10K = 1e22; // 1e4 = 10K tokens with 18 decimals
    uint256 constant TOKEN_100K = 1e23; // 1e5 = 100K tokens with 18 decimals
    uint256 constant TOKEN_1M = 1e24; // 1e6 = 1M tokens with 18 decimals
    uint256 constant TOKEN_10M = 1e25; // 1e7 = 10M tokens with 18 decimals
    uint256 constant TOKEN_100M = 1e26; // 1e8 = 100M tokens with 18 decimals
    uint256 constant TOKEN_10B = 1e28; // 1e10 = 10B tokens with 18 decimals

    uint256 constant DURATION = 7 days;
    uint256 constant WEEK = 1 weeks;
    /// @dev Use same value as in voting escrow
    uint256 constant MAXTIME = 2 * 365 * 86400;
    uint256 constant MAX_BPS = 10_000;

    address owner;
    address owner2;
    address owner3;
    address owner4;
    address owner5;
    address[] owners;
    IERC20 USDC;
    IERC20 FRAX;
    IERC20 DAI;
    MockERC20 LR; // late reward

    address pool1;
    address pool2;
    address pool3;

    uint256 chainId1;
    uint256 chainId2;
    uint256 chainId3;

    uint160 poolId1;
    uint160 poolId2;
    uint160 poolId3;

    FeesVotingReward feesVotingReward;
    BribeVotingReward bribeVotingReward;
    FeesVotingReward feesVotingReward2;
    BribeVotingReward bribeVotingReward2;
    FeesVotingReward feesVotingReward3;
    BribeVotingReward bribeVotingReward3;

    SigUtils sigUtils;

    /// @dev set MAINNET_RPC_URL in .env to run mainnet tests
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    /// @dev expected values in tests are adjusted to match this block number
    uint256 BLOCK_NUMBER = 18244804;

    /// @dev Mainnet fork at given block number + v2 deployment if Deployment.FORK selected
    ///      Only Mainnet fork at last block if Deployment.CUSTOM selected
    ///      _setUp can be overriden to provide additional configuration if desired
    function setUp() public {
        if (deploymentType == Deployment.FORK) {
            _forkSetup();
        } else if (deploymentType == Deployment.CUSTOM) {
            _customSetup();
        }
        _setUp();
    }

    /// @dev Implement this if you want a custom configured deployment
    function _setUp() public virtual {}

    function _forkSetup() public {
        vm.selectFork(vm.createFork(MAINNET_RPC_URL, BLOCK_NUMBER));
        // timestamp : 1696031999
        skipToNextEpoch(1); // makes timestamps calculations easier in tests
        // timestamp : 1696464001
        _testSetupBefore();
        _coreSetup();
        _testSetupAfter();
    }

    function _customSetup() public {
        vm.selectFork(vm.createFork(MAINNET_RPC_URL));
    }

    function _testSetupBefore() public {
        // seed set up with initial time
        skip(1 weeks);

        escrow = IVotingEscrow(0xC5ca1EBF6e912E49A6a70Bb0385Ea065061a4F09); // mainnet veAPW

        dao = makeAddr("SpectraDAO");
        emergencyCouncil = makeAddr("SpectraEmergencyCouncil");
        feesVotingRewardsDistributor = makeAddr("FeesVotingRewardsDistributor");

        deployAccessManager();

        pool1 = makeAddr("Pool1");
        pool2 = makeAddr("Pool2");
        pool3 = makeAddr("Pool3");

        chainId1 = 11;
        chainId1 = 22;
        chainId1 = 33;

        poolsToRegister.push(PoolToRegister({addr: pool1, chainId: chainId1}));
        poolsToRegister.push(PoolToRegister({addr: pool2, chainId: chainId2}));
        poolsToRegister.push(PoolToRegister({addr: pool3, chainId: chainId3}));

        deployOwners();
        deployCoins();
        mintStables();
        uint256[] memory amounts = new uint256[](5);
        amounts[0] = TOKEN_10M;
        amounts[1] = TOKEN_10M;
        amounts[2] = TOKEN_10M;
        amounts[3] = TOKEN_10M;
        amounts[4] = TOKEN_10M;
        mintToken(address(APW), owners, amounts);
        mintToken(address(LR), owners, amounts);

        tokens.push(address(USDC));
        tokens.push(address(FRAX));
        tokens.push(address(DAI));
        tokens.push(address(APW));
        tokens.push(address(LR));
    }

    function _testSetupAfter() public {
        accessManager.grantRole(Roles.VOTER_GOVERNOR_ROLE, dao, 0);
        accessManager.revokeRole(Roles.VOTER_GOVERNOR_ROLE, address(this));

        poolId1 = governanceRegistry.getPoolId(pool1, chainId1);
        poolId2 = governanceRegistry.getPoolId(pool2, chainId2);
        poolId3 = governanceRegistry.getPoolId(pool3, chainId3);

        // pool 1
        voter.createVotingRewards(poolId1);
        feesVotingReward = FeesVotingReward(voter.poolToFees(poolId1));
        bribeVotingReward = BribeVotingReward(voter.poolToBribe(poolId1));

        // pool 2
        voter.createVotingRewards(poolId2);
        feesVotingReward2 = FeesVotingReward(voter.poolToFees(poolId2));
        bribeVotingReward2 = BribeVotingReward(voter.poolToBribe(poolId2));

        // set default DAO fee on fees voting rewards to 1%
        vm.startPrank(dao);
        voter.setDefaultFeesRewardsDaoFee(100);
        voter.setDefaultBribeRewardsDaoFee(100);
        vm.stopPrank();

        // pool 3
        voter.createVotingRewards(poolId3);
        feesVotingReward3 = FeesVotingReward(voter.poolToFees(poolId3));
        bribeVotingReward3 = BribeVotingReward(voter.poolToBribe(poolId3));

        bytes32 domainSeparator = keccak256(
            abi.encode(
                bytes32("hfhfh"),
                keccak256(bytes(escrow.name())),
                keccak256(bytes(escrow.version())),
                block.chainid,
                address(escrow)
            )
        );
        sigUtils = new SigUtils(domainSeparator);

        vm.label(address(owner), "Owner");
        vm.label(address(owner2), "Owner 2");
        vm.label(address(owner3), "Owner 3");
        vm.label(address(owner4), "Owner 4");
        vm.label(address(owner5), "Owner 5");
        vm.label(address(USDC), "USDC");
        vm.label(address(FRAX), "FRAX");
        vm.label(address(DAI), "DAI");
        vm.label(address(LR), "Bribe Voting Reward");
        vm.label(address(pool1), "Pool 1");
        vm.label(address(pool2), "Pool 2");
        vm.label(address(pool3), "Pool 3");

        vm.label(address(escrow), "Voting Escrow");
        vm.label(address(governanceRegistry), "Governance Registry");
        vm.label(address(votingRewardsFactory), "Voting Rewards Factory");
        vm.label(address(voter), "Voter");
        vm.label(address(feesVotingReward), "Fees Voting Reward 1");
        vm.label(address(bribeVotingReward), "Bribe Voting Reward 1");
        vm.label(address(feesVotingReward2), "Fees Voting Reward 2");
        vm.label(address(bribeVotingReward2), "Bribe Voting Reward 2");
        vm.label(address(feesVotingReward3), "Fees Voting Reward 3");
        vm.label(address(bribeVotingReward3), "Bribe Voting Reward 3");
    }

    function deployOwners() public {
        owner = makeAddr("owner");
        owner2 = makeAddr("owner2");
        owner3 = makeAddr("owner3");
        owner4 = makeAddr("owner4");
        owner5 = makeAddr("owner5");
        owners = new address[](5);
        owners[0] = address(owner);
        owners[1] = address(owner2);
        owners[2] = address(owner3);
        owners[3] = address(owner4);
        owners[4] = address(owner5);
    }

    function deployCoins() public {
        if (deploymentType == Deployment.FORK) {
            USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); //0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
            DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F); //0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
            FRAX = IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e); //0x2E3D870790dC77A83DD1d18184Acc7439A53f475);
        } else {
            USDC = IERC20(new MockERC20("USDC", "USDC", 6));
            DAI = IERC20(new MockERC20("DAI", "DAI", 18));
            FRAX = new MockERC20("FRAX", "FRAX", 18);
        }
        APW = IERC20(0x4104b135DBC9609Fc1A9490E61369036497660c8);
        LR = new MockERC20("LR", "LR", 18);
    }

    function deployAccessManager() public {
        accessManager = new AccessManager(address(this));
        accessManager.grantRole(Roles.REGISTRY_ROLE, address(this), 0);
        accessManager.grantRole(Roles.VOTER_GOVERNOR_ROLE, address(this), 0);
        accessManager.grantRole(Roles.VOTER_EMERGENCY_COUNCIL_ROLE, emergencyCouncil, 0);
        accessManager.grantRole(Roles.FEES_VOTING_REWARDS_DISTRIBUTOR_ROLE, feesVotingRewardsDistributor, 0);
    }

    function mintStables() public {
        deal(address(USDC), feesVotingRewardsDistributor, 1e12 * USDC_1, true);
        deal(address(FRAX), feesVotingRewardsDistributor, 1e12 * TOKEN_1, true);
        deal(address(DAI), feesVotingRewardsDistributor, 1e12 * TOKEN_1, true);
        for (uint256 i = 0; i < owners.length; i++) {
            deal(address(USDC), owners[i], 1e12 * USDC_1, true);
            deal(address(FRAX), owners[i], 1e12 * TOKEN_1, true);
            deal(address(DAI), owners[i], 1e12 * TOKEN_1, true);
        }
    }

    function mintToken(address _token, address[] memory _accounts, uint256[] memory _amounts) public {
        for (uint256 i = 0; i < _amounts.length; i++) {
            deal(address(_token), _accounts[i], _amounts[i], true);
        }
    }

    function dealETH(address[] memory _accounts, uint256[] memory _amounts) public {
        for (uint256 i = 0; i < _accounts.length; i++) {
            vm.deal(_accounts[i], _amounts[i]);
        }
    }

    /// @dev Helper utility to forward time to next week
    ///      note epoch requires at least one second to have
    ///      passed into the new epoch
    function skipToNextEpoch(uint256 offset) public {
        uint256 ts = block.timestamp;
        uint256 nextEpoch = ts - (ts % (1 weeks)) + (1 weeks);
        vm.warp(nextEpoch + offset);
        vm.roll(block.number + 1);
    }

    function skipAndRoll(uint256 timeOffset) public {
        skip(timeOffset);
        vm.roll(block.number + 1);
    }

    /// @dev Helper utility to get start of epoch based on timestamp
    function _getEpochStart(uint256 _timestamp) internal pure returns (uint256) {
        return _timestamp - (_timestamp % (7 days));
    }

    /// @dev Used to convert IVotingEscrow int128s to uint256
    ///      These values are always positive
    function convert(int128 _amount) internal pure returns (uint256) {
        return uint256(uint128(_amount));
    }
}
