// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "./BaseTest.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC721, IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import {VyperDeployer} from "./utils/VyperDeployer.sol";

contract VotingEscrowTest is BaseTest {
    event NotifyReward(address indexed from, address indexed reward, uint256 indexed epoch, uint256 amount);

    // function testDeployEscrow() public {
    //     VyperDeployer vyperDeployer = new VyperDeployer();

    //     string memory _name = "New Vote-escrowed APWine Token";
    //     string memory _symbol = "nveAPW";
    //     string memory _version = "2";

    //     IVotingEscrow newEscrow = IVotingEscrow(
    //         vyperDeployer.deployContract(
    //             "contracts/staking/VotingEscrow.vy",
    //             abi.encode(address(APW), _name, _symbol, _version)
    //         )
    //     );

    //     assertEq(newEscrow.name(), _name);
    //     assertEq(newEscrow.version(), _version);
    //     assertEq(newEscrow.admin(), address(vyperDeployer));
    // }

    function testDepositFor() public {
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);

        IVotingEscrow.LockedBalance memory preLocked = escrow.locked(address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.deposit_for(address(owner), TOKEN_1);
        IVotingEscrow.LockedBalance memory postLocked = escrow.locked(address(owner));

        assertEq(uint256(uint128(postLocked.end)), uint256(uint128(preLocked.end)));
        assertEq(uint256(uint128(postLocked.amount)) - uint256(uint128(preLocked.amount)), TOKEN_1);
    }

    function testIncreaseAmount() public {
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + block.timestamp);

        IVotingEscrow.LockedBalance memory preLocked = escrow.locked(address(owner));
        APW.approve(address(escrow), TOKEN_1);
        //vm.expectEmit(false, false, false, true, address(escrow));
        //emit MetadataUpdate(address(owner));
        escrow.increase_amount(TOKEN_1);
        IVotingEscrow.LockedBalance memory postLocked = escrow.locked(address(owner));

        assertEq(uint256(uint128(postLocked.end)), uint256(uint128(preLocked.end)));
        assertEq(uint256(uint128(postLocked.amount)) - uint256(uint128(preLocked.amount)), TOKEN_1);
    }

    function testIncreaseUnlockTime() public {
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, 4 weeks + block.timestamp);

        skip((1 weeks) / 2);

        IVotingEscrow.LockedBalance memory preLocked = escrow.locked(address(owner));
        //vm.expectEmit(false, false, false, true, address(escrow));
        //emit MetadataUpdate(address(owner));
        escrow.increase_unlock_time(MAXTIME + block.timestamp);
        IVotingEscrow.LockedBalance memory postLocked = escrow.locked(address(owner));

        uint256 expectedLockTime = ((block.timestamp + MAXTIME) / WEEK) * WEEK;
        assertEq(uint256(uint128(postLocked.end)), expectedLockTime);
        assertEq(uint256(uint128(postLocked.amount)), uint256(uint128(preLocked.amount)));
    }

    function testCreateLock() public {
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), 1e25);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week

        // Balance should be zero before and 1 after creating the lock
        assertEq(escrow.balanceOf(address(owner)), 0);
        escrow.create_lock(1e25, lockDuration + block.timestamp);
        vm.stopPrank();
        assertEq(escrow.balanceOf(address(owner)), 95890252409944190450668);
    }

    function testCreateLockOutsideAllowedZones() public {
        APW.approve(address(escrow), 1e25);
        vm.startPrank(address(owner), address(owner));
        vm.expectRevert();
        escrow.create_lock(1e21, MAXTIME + 1 weeks + block.timestamp);
        vm.stopPrank();
    }

    function testIncreaseAmountWithNormalLock() public {
        // timestamp : 1697068801
        uint256 timestamp0 = block.timestamp;

        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, MAXTIME + timestamp0);

        skipAndRoll(1);
        uint256 timestamp1 = block.timestamp;

        uint256 epoch_ = escrow.epoch();

        APW.approve(address(escrow), TOKEN_1);
        escrow.increase_amount(TOKEN_1);

        // check locked balance state is updated correctly
        IVotingEscrow.LockedBalance memory locked = escrow.locked(address(owner));
        assertEq(convert(locked.amount), TOKEN_1 * 2);
        assertEq(locked.end, ((MAXTIME + timestamp0) / WEEK) * WEEK);

        // check user point updates correctly
        assertEq(escrow.user_point_epoch(address(owner)), 2);
        IVotingEscrow.UserPoint memory userPoint = escrow.user_point_history(address(owner), 2);
        assertEq(convert(userPoint.slope), 31709791983); // (TOKEN_1 * 2) / MAXTIME
        assertEq(convert(userPoint.bias), 31709791983 * (locked.end - timestamp1));
        assertEq(userPoint.ts, block.timestamp);
        assertEq(userPoint.blk, block.number);

        // check global point updates correctly
        assertEq(escrow.epoch(), epoch_ + 1);
        IVotingEscrow.GlobalPoint memory globalPoint = escrow.point_history(escrow.epoch());
        assertEq(globalPoint.ts, block.timestamp);
        assertEq(globalPoint.blk, block.number);

        assertEq(escrow.slope_changes(locked.end), -31709791983);
        vm.stopPrank();
    }

    function testCannotWithdrawBeforeLockExpiry() public {
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        escrow.create_lock(TOKEN_1, lockDuration + block.timestamp);
        skipAndRoll(1);

        vm.expectRevert();
        escrow.withdraw();
    }

    function testWithdraw() public {
        vm.startPrank(address(owner), address(owner));
        APW.approve(address(escrow), TOKEN_1);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        escrow.create_lock(TOKEN_1, lockDuration + block.timestamp);
        uint256 preBalance = APW.balanceOf(address(owner));

        skipAndRoll(lockDuration);
        escrow.withdraw();

        uint256 postBalance = APW.balanceOf(address(owner));
        assertEq(postBalance - preBalance, TOKEN_1);
        assertEq(escrow.balanceOf(address(owner)), 0);
    }
}
