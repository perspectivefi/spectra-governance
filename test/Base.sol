// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import {AccessManager, IAccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Roles} from "contracts/libraries/Roles.sol";
import {SigUtils} from "test/utils/SigUtils.sol";
import {SafeCastLibrary} from "contracts/libraries/SafeCastLibrary.sol";
import {IVotingEscrow} from "contracts/interfaces/IVotingEscrow.sol";
import {VotingRewardsFactory, IVotingRewardsFactory} from "contracts/factories/VotingRewardsFactory.sol";
import {GovernanceRegistry, IGovernanceRegistry} from "contracts/GovernanceRegistry.sol";
import {IVotingReward} from "contracts/rewards/VotingReward.sol";
import {FeesVotingReward} from "contracts/rewards/FeesVotingReward.sol";
import {BribeVotingReward} from "contracts/rewards/BribeVotingReward.sol";
import {IVoter, Voter} from "contracts/Voter.sol";
import {SpectraForwarder} from "contracts/SpectraForwarder.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

/// @notice Base contract used for tests and deployment scripts
abstract contract Base is Script, Test {
    enum Deployment {
        FORK,
        CUSTOM
    }

    struct PoolToRegister {
        address addr;
        uint256 chainId;
    }

    /// @dev Determines whether or not to use the base set up configuration
    ///      Fork deployment used by default
    Deployment deploymentType = Deployment.FORK;

    IERC20 public APW;
    IVotingEscrow public escrow;

    address[] public tokens;

    PoolToRegister[] public poolsToRegister;

    AccessManager accessManager;

    address dao;
    address emergencyCouncil;
    address feesVotingRewardsDistributor;

    /// @dev Governance Deployment
    SpectraForwarder public forwarder;
    GovernanceRegistry public governanceRegistry;
    VotingRewardsFactory public votingRewardsFactory;
    Voter public voter;

    bytes4[] private registry_methods_selectors = new bytes4[](3);
    bytes4[] private voter_governor_methods_selectors = new bytes4[](9);
    bytes4[] private voter_emergency_council_methods_selectors = new bytes4[](2);
    bytes4[] private voting_rewards_factory_methods_selectors = new bytes4[](1);

    function _coreSetup() public {
        registry_methods_selectors[0] = IGovernanceRegistry(address(0)).setVotingRewardsFactory.selector;
        registry_methods_selectors[1] = IGovernanceRegistry(address(0)).setPoolRegistration.selector;
        registry_methods_selectors[2] = IGovernanceRegistry(address(0)).setPoolsRegistration.selector;

        voter_governor_methods_selectors[0] = IVoter(address(0)).initialize.selector;
        voter_governor_methods_selectors[1] = IVoter(address(0)).setMaxVotingNum.selector;
        voter_governor_methods_selectors[2] = IVoter(address(0)).setDefaultFeesRewardsDaoFee.selector;
        voter_governor_methods_selectors[3] = IVoter(address(0)).setDefaultBribeRewardsDaoFee.selector;
        voter_governor_methods_selectors[4] = IVoter(address(0)).setPoolsVotingRewardsDaoFee.selector;
        voter_governor_methods_selectors[5] = IVoter(address(0)).setVotingRewardsDaoFee.selector;
        voter_governor_methods_selectors[6] = IVoter(address(0)).setRestrictedUser.selector;
        voter_governor_methods_selectors[7] = IVoter(address(0)).whitelistBribeToken.selector;
        voter_governor_methods_selectors[8] = IVoter(address(0)).whitelistUser.selector;

        voter_emergency_council_methods_selectors[0] = IVoter(address(0)).banVote.selector;
        voter_emergency_council_methods_selectors[1] = IVoter(address(0)).reauthorizeVote.selector;

        voting_rewards_factory_methods_selectors[0] = IVotingRewardsFactory(address(0)).createRewards.selector;

        // Deployments
        forwarder = new SpectraForwarder();
        votingRewardsFactory = new VotingRewardsFactory(address(accessManager));
        governanceRegistry = new GovernanceRegistry(address(accessManager));
        voter = new Voter(
            dao,
            address(accessManager),
            address(forwarder),
            address(escrow),
            address(governanceRegistry),
            0,
            0
        );

        // Setup VotingRewardsFactory
        accessManager.setTargetFunctionRole(
            address(votingRewardsFactory),
            voting_rewards_factory_methods_selectors,
            Roles.VOTER_ROLE
        );
        accessManager.grantRole(Roles.ADMIN_ROLE, address(votingRewardsFactory), 0);

        // Setup GovernanceRegistry
        accessManager.setTargetFunctionRole(
            address(governanceRegistry),
            registry_methods_selectors,
            Roles.REGISTRY_ROLE
        );
        governanceRegistry.setVotingRewardsFactory(address(votingRewardsFactory));
        if (poolsToRegister.length > 0) {
            uint256 _length = poolsToRegister.length;
            address[] memory poolsAddr = new address[](_length);
            uint256[] memory poolsChainId = new uint256[](_length);
            for (uint256 i; i < _length; i++) {
                poolsAddr[i] = poolsToRegister[i].addr;
                poolsChainId[i] = poolsToRegister[i].chainId;
            }
            governanceRegistry.setPoolsRegistration(poolsAddr, poolsChainId, true);
        }

        // Setup Voter
        accessManager.setTargetFunctionRole(
            address(voter),
            voter_governor_methods_selectors,
            Roles.VOTER_GOVERNOR_ROLE
        );
        if (tokens.length > 0) {
            voter.initialize(tokens);
        }
        accessManager.setTargetFunctionRole(
            address(voter),
            voter_emergency_council_methods_selectors,
            Roles.VOTER_EMERGENCY_COUNCIL_ROLE
        );
        accessManager.grantRole(Roles.VOTER_ROLE, address(voter), 0);
    }
}
