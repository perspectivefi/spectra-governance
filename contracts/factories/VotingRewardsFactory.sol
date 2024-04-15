// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {Roles} from "../libraries/Roles.sol";
import {IVotingRewardsFactory} from "../interfaces/factories/IVotingRewardsFactory.sol";
import {IVotingReward} from "../interfaces/IVotingReward.sol";
import {FeesVotingReward} from "../rewards/FeesVotingReward.sol";
import {BribeVotingReward} from "../rewards/BribeVotingReward.sol";

contract VotingRewardsFactory is IVotingRewardsFactory, AccessManaged {
    bytes4 constant _DEPOSIT_SELECTOR = IVotingReward(address(0))._deposit.selector;
    bytes4 constant _WITHDRAW_SELECTOR = IVotingReward(address(0))._withdraw.selector;
    bytes4 constant GET_REWARD_SELECTOR = IVotingReward(address(0)).getReward.selector;
    bytes4 constant GET_REWARDS_SELECTOR = IVotingReward(address(0)).getRewards.selector;
    bytes4 constant SET_DAO_FEE_SELECTOR = IVotingReward(address(0)).setDaoFee.selector;
    bytes4 constant NOTIFY_REWARD_AMOUNT_SELECTOR = IVotingReward(address(0)).notifyRewardAmount.selector;
    bytes4 constant NOTIFY_REWARD_AMOUNT_ETH_SELECTOR = IVotingReward(address(0)).notifyRewardAmountETH.selector;

    constructor(address _initialAuthority) AccessManaged(_initialAuthority) {}

    /// @inheritdoc IVotingRewardsFactory
    function createRewards(
        uint160 _poolId,
        address _dao,
        address _initialAuthority,
        address _forwarder,
        address _initialRewardToken,
        uint256 _feesDaoFee,
        uint256 _bribeDaoFee
    ) external restricted returns (address feesVotingReward, address bribeVotingReward) {
        feesVotingReward = address(
            new FeesVotingReward(
                _poolId,
                _dao,
                _initialAuthority,
                _forwarder,
                msg.sender,
                _initialRewardToken,
                _feesDaoFee
            )
        );
        bribeVotingReward = address(
            new BribeVotingReward(
                _poolId,
                _dao,
                _initialAuthority,
                _forwarder,
                msg.sender,
                _initialRewardToken,
                _bribeDaoFee
            )
        );
        IAccessManager(_initialAuthority).setTargetFunctionRole(
            feesVotingReward,
            _getVRVoterReservedFunctionsSelectors(),
            Roles.VOTER_ROLE
        );
        IAccessManager(_initialAuthority).setTargetFunctionRole(
            bribeVotingReward,
            _getVRVoterReservedFunctionsSelectors(),
            Roles.VOTER_ROLE
        );
        IAccessManager(_initialAuthority).setTargetFunctionRole(
            feesVotingReward,
            _getVRNotifyRewardAmountSelectors(),
            Roles.FEES_VOTING_REWARDS_DISTRIBUTOR_ROLE
        );
    }

    /// @notice Getter for selectors of VotingReward's functions reserved to Voter contract, used for access management
    function _getVRVoterReservedFunctionsSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = _DEPOSIT_SELECTOR;
        selectors[1] = _WITHDRAW_SELECTOR;
        selectors[2] = GET_REWARD_SELECTOR;
        selectors[3] = GET_REWARDS_SELECTOR;
        selectors[4] = SET_DAO_FEE_SELECTOR;
        return selectors;
    }

    /// @notice Getter for selectors of VotingReward's notifyRewardAmount functions, used for access management
    function _getVRNotifyRewardAmountSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = NOTIFY_REWARD_AMOUNT_SELECTOR;
        selectors[1] = NOTIFY_REWARD_AMOUNT_ETH_SELECTOR;
        return selectors;
    }
}
