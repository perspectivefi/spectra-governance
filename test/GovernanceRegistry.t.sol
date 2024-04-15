// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "./BaseTest.sol";

contract VoterTest is BaseTest {
    function testCannotSetVotingRewardsFactoryWithoutRegistryRole() public {
        vm.prank(address(owner2));
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, owner2));
        governanceRegistry.setVotingRewardsFactory(address(0));
    }

    function testCannotSetPoolRegistrationWithoutRegistryRole() public {
        vm.prank(address(owner2));
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, owner2));
        governanceRegistry.setPoolRegistration(address(0), 0, true);
    }

    function testSetVotingRewardsFactory() public {
        assertEq(governanceRegistry.votingRewardsFactory(), address(votingRewardsFactory));
        vm.prank(address(this));
        governanceRegistry.setVotingRewardsFactory(address(1));
        assertEq(governanceRegistry.votingRewardsFactory(), address(1));
    }

    function testSetPoolRegistration() public {
        address _pool = address(1);
        uint256 _chainId = 1;
        uint160 _poolId = governanceRegistry.getPoolId(_pool, _chainId);

        assertEq(governanceRegistry.isPoolRegistered(_pool, _chainId), false);
        assertEq(governanceRegistry.isPoolRegistered(_poolId), false);

        vm.prank(address(this));
        governanceRegistry.setPoolRegistration(_pool, _chainId, true);

        assertEq(governanceRegistry.isPoolRegistered(_pool, _chainId), true);
        assertEq(governanceRegistry.isPoolRegistered(_poolId), true);
    }

    function testGetPoolId() public {
        address _pool = address(1);
        uint256 _chainId = 1;
        uint160 _expectedPoolId = 0;
        uint160 _actualPoolId = governanceRegistry.getPoolId(_pool, _chainId);
        assertEq(_expectedPoolId, _actualPoolId);
    }
}
