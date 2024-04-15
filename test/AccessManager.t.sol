// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "./BaseTest.sol";

contract AccessManagerTest is BaseTest {
    address AMSuperAdmin2 = 0x00000000000000000000000000000000000000A2;

    function testAccessManagerAccess() public {
        assertEq(address(accessManager), governanceRegistry.authority());
        assertEq(address(accessManager), voter.authority());
        assertEq(address(accessManager), feesVotingReward.authority());
        assertEq(address(accessManager), bribeVotingReward.authority());
        assertEq(address(accessManager), feesVotingReward2.authority());
        assertEq(address(accessManager), bribeVotingReward2.authority());
        assertEq(address(accessManager), feesVotingReward3.authority());
        assertEq(address(accessManager), bribeVotingReward3.authority());

        // Only a super admin can grant roles. So AMSuperAdmin2 cannot grant super admin role to MOCK_ADDR_1
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManager.AccessManagerUnauthorizedAccount.selector,
                AMSuperAdmin2,
                Roles.ADMIN_ROLE
            )
        );
        vm.prank(AMSuperAdmin2);
        accessManager.grantRole(Roles.ADMIN_ROLE, owner, 0);

        // Now address(this) can grant super admin role to MOCK_ADDR_1
        accessManager.grantRole(Roles.ADMIN_ROLE, owner, 0);
    }

    function testChangeVoterAccessManagerInstance() public {
        vm.prank(owner2);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, owner2));
        voter.setMaxVotingNum(100);

        // New access manager instance created with super admin AMSuperAdmin2
        AccessManager accessManager2 = new AccessManager(AMSuperAdmin2);

        // AMSuperAdmin2 grants VOTER_GOVERNOR_ROLE to owner2
        vm.prank(AMSuperAdmin2);
        accessManager2.grantRole(Roles.VOTER_GOVERNOR_ROLE, owner2, 0);

        // Change the access manager authority instance to the new one for voter
        accessManager.updateAuthority(address(voter), address(accessManager2));

        // owner2 cannot call voter.setMaxVotingNum()
        vm.prank(owner2);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, owner2));
        voter.setMaxVotingNum(100);

        // Attribute role to voter.setMaxVotingNum() in accessManager2
        bytes4[] memory voter_governor_methods_selectors = new bytes4[](1);
        voter_governor_methods_selectors[0] = IVoter(address(0)).setMaxVotingNum.selector;
        vm.prank(AMSuperAdmin2);
        accessManager2.setTargetFunctionRole(
            address(voter),
            voter_governor_methods_selectors,
            Roles.VOTER_GOVERNOR_ROLE
        );

        // owner2 is now able to call voter.setMaxVotingNum()
        vm.prank(owner2);
        voter.setMaxVotingNum(100);
    }

    function testChangeVotingRewardAccessManagerInstance() public {
        vm.prank(owner2);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, owner2));
        voter.setMaxVotingNum(100);

        // A new access manager instance is created with super admin AMSuperAdmin2
        AccessManager accessManager2 = new AccessManager(AMSuperAdmin2);

        // AMSuperAdmin2 grants VOTER_GOVERNOR_ROLE to owner2
        vm.prank(AMSuperAdmin2);
        accessManager2.grantRole(Roles.FEES_VOTING_REWARDS_DISTRIBUTOR_ROLE, owner2, 0);

        // Change access manager authority instance to the new one for feesVotingReward
        accessManager.updateAuthority(address(feesVotingReward), address(accessManager2));

        // Change access manager authority instance to the new one for voter
        accessManager.updateAuthority(address(voter), address(accessManager2));
        // AMSuperAdmin2 grants VOTER_ROLE to voter
        vm.prank(AMSuperAdmin2);
        accessManager2.grantRole(Roles.VOTER_ROLE, address(voter), 0);

        // Change access manager authority instance to the new one for governanceRegistry
        accessManager.updateAuthority(address(governanceRegistry), address(accessManager2));

        // Change access manager authority instance to the new one for votingRewardsFactory
        accessManager.updateAuthority(address(votingRewardsFactory), address(accessManager2));
        // AMSuperAdmin2 grants ADMIN_ROLE to votingRewardsFactory
        vm.prank(AMSuperAdmin2);
        accessManager2.grantRole(Roles.ADMIN_ROLE, address(votingRewardsFactory), 0);

        // Attribute role to votingRewardsFactory.createRewards() in accessManager2
        bytes4[] memory voting_rewards_factory_methods_selectors = new bytes4[](1);
        voting_rewards_factory_methods_selectors[0] = IVotingRewardsFactory(address(0)).createRewards.selector;
        vm.prank(AMSuperAdmin2);
        accessManager2.setTargetFunctionRole(
            address(votingRewardsFactory),
            voting_rewards_factory_methods_selectors,
            Roles.VOTER_ROLE
        );

        // deploy feesVotingReward4 for new pool4
        address pool4 = makeAddr("Pool4");
        uint256 chainId4 = 44;
        vm.prank(AMSuperAdmin2);
        governanceRegistry.setPoolRegistration(pool4, chainId4, true);
        uint160 poolId4 = governanceRegistry.getPoolId(pool4, chainId4);
        (address feesVotingReward4Addr, ) = voter.createVotingRewards(poolId4);
        FeesVotingReward feesVotingReward4 = FeesVotingReward(feesVotingReward4Addr);

        vm.deal(owner2, 2 ether);

        // owner2 is able to send rewards to feesVotingReward4 but not to feesVotingReward
        vm.startPrank(owner2);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, owner2));
        feesVotingReward.notifyRewardAmountETH{value: 1 ether}();
        feesVotingReward4.notifyRewardAmountETH{value: 1 ether}();
        vm.stopPrank();

        // Attribute role to feesVotingReward.notifyRewardAmountETH() in accessManager2
        bytes4[] memory voter_governor_methods_selectors = new bytes4[](1);
        voter_governor_methods_selectors[0] = IVotingReward(address(0)).notifyRewardAmountETH.selector;
        vm.prank(AMSuperAdmin2);
        accessManager2.setTargetFunctionRole(
            address(feesVotingReward),
            voter_governor_methods_selectors,
            Roles.FEES_VOTING_REWARDS_DISTRIBUTOR_ROLE
        );

        // owner2 is now able to send rewards to feesVotingReward
        vm.prank(owner2);
        feesVotingReward.notifyRewardAmountETH{value: 1 ether}();
    }
}
