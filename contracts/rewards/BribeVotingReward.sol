// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import {IVoter} from "../interfaces/IVoter.sol";
import {VotingReward} from "./VotingReward.sol";

/// @notice Bribes pay out rewards for a given pool based on the votes that were received from the user (goes hand in hand with Voter.vote())
contract BribeVotingReward is VotingReward {
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
    function notifyRewardAmount(address _token, uint256 _amount) external override nonReentrant {
        address sender = _msgSender();

        if (!IVoter(voter).isVoteAuthorized(poolId)) revert PoolBanned();
        if (!isReward[_token]) {
            if (!IVoter(voter).isWhitelistedBribeToken(_token)) revert NotWhitelistedReward();
            isReward[_token] = true;
            rewards.push(_token);
        }

        _notifyRewardAmount(sender, _token, _amount);
    }

    /// @inheritdoc VotingReward
    function notifyRewardAmountETH() external payable override nonReentrant {
        address sender = _msgSender();

        if (!IVoter(voter).isVoteAuthorized(poolId)) revert PoolBanned();
        if (!isReward[ETH]) {
            if (!IVoter(voter).isWhitelistedBribeToken(ETH)) revert NotWhitelistedReward();
            isReward[ETH] = true;
            rewards.push(ETH);
        }

        _notifyRewardAmount(sender, ETH, msg.value);
    }
}
