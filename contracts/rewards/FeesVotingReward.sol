// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import {VotingReward} from "./VotingReward.sol";
import {IVoter} from "../interfaces/IVoter.sol";

/// @notice Fees pay out rewards for a given pool based on the votes that were received from the user (goes hand in hand with Voter.vote())
contract FeesVotingReward is VotingReward {
    constructor(
        uint160 _poolId,
        address _dao,
        address _initialAuthority,
        address _forwarder,
        address _voter,
        address _initialRewardToken,
        uint256 _daoFee
    ) VotingReward(_poolId, _dao, _initialAuthority, _forwarder, _voter, _initialRewardToken, _daoFee) {}

    /// @inheritdoc VotingReward
    function notifyRewardAmount(address _token, uint256 _amount) external override nonReentrant restricted {
        if (!isReward[_token]) {
            isReward[_token] = true;
            rewards.push(_token);
        }

        _notifyRewardAmount(_msgSender(), _token, _amount);
    }

    /// @inheritdoc VotingReward
    function notifyRewardAmountETH() external payable override nonReentrant restricted {
        if (!isReward[ETH]) {
            isReward[ETH] = true;
            rewards.push(ETH);
        }

        _notifyRewardAmount(_msgSender(), ETH, msg.value);
    }
}
