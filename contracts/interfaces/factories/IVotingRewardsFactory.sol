// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVotingRewardsFactory {
    /// @notice creates a BribeVotingReward and a FeesVotingReward contract for a pool
    /// @param _poolId              Identifier of the pool
    /// @param _dao                 Address of the DAO
    /// @param _initialAuthority    Address of access manager
    /// @param _forwarder           Address of trusted forwarder
    /// @param _initialRewardToken  Addresses of initial reward token
    /// @param _feesDaoFee          Default value of fees voting rewards to be sent to the DAO, in basis points
    /// @param _bribeDaoFee         Default value of bribe voting rewards to be sent to the DAO, in basis points
    /// @return feesVotingReward    Address of FeesVotingReward contract created
    /// @return bribeVotingReward   Address of BribeVotingReward contract created
    function createRewards(
        uint160 _poolId,
        address _dao,
        address _initialAuthority,
        address _forwarder,
        address _initialRewardToken,
        uint256 _feesDaoFee,
        uint256 _bribeDaoFee
    ) external returns (address feesVotingReward, address bribeVotingReward);
}
