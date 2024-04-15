// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVotingReward {
    error FeeTooHigh();
    error NotWhitelistedReward();
    error PoolBanned();
    error ZeroAmount();

    event Deposit(address indexed from, address indexed user, uint256 amount);
    event Withdraw(address indexed from, address indexed user, uint256 amount);
    event NotifyReward(address indexed from, address indexed reward, uint256 indexed epoch, uint256 amount);
    event ClaimRewards(address indexed from, address indexed reward, uint256 amount);
    event DaoFeeChange(uint256 indexed oldFee, uint256 indexed newFee);

    /// @notice A checkpoint for marking balance
    struct Checkpoint {
        uint256 timestamp;
        uint256 balanceOf;
    }

    /// @notice A checkpoint for marking supply
    struct SupplyCheckpoint {
        uint256 timestamp;
        uint256 supply;
    }

    /// @notice Epoch duration constant (7 days)
    function DURATION() external view returns (uint256);

    /// @notice Address of DAO
    function dao() external view returns (address);

    /// @notice Address of Voter.sol
    function voter() external view returns (address);

    /// @notice ID of the pool this contrat is associated with
    function poolId() external view returns (uint160);

    /// @notice Total amount currently deposited via _deposit()
    function totalSupply() external view returns (uint256);

    /// @notice Current amount deposited by address
    function balanceOf(address _user) external view returns (uint256);

    /// @notice Amount of tokens to reward depositors for a given epoch
    /// @param _token Address of token to reward
    /// @param _epochStart Startime of rewards epoch
    /// @return Amount of token
    function tokenRewardsPerEpoch(address _token, uint256 _epochStart) external view returns (uint256);

    /// @notice Most recent timestamp a user has claimed their rewards for given tokens
    /// @param  _token Address of token rewarded
    /// @param  _user address of the user
    /// @return Timestamp
    function lastEarn(address _token, address _user) external view returns (uint256);

    /// @notice True if a token is or has been an active reward token, else false
    function isReward(address _token) external view returns (bool);

    /// @notice Share of rewards to be sent to the DAO, in basis points
    function daoFee() external view returns (uint256);

    /// @notice The number of checkpoints for each user address
    function numCheckpoints(address _user) external view returns (uint256);

    /// @notice The total number of checkpoints
    function supplyNumCheckpoints() external view returns (uint256);

    /// @notice Determine the prior balance for an account as of a block number
    /// @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
    /// @param _user        Address of the user to check
    /// @param _timestamp   The timestamp to get the balance at
    /// @return The balance the account had as of the given block
    function getPriorBalanceIndex(address _user, uint256 _timestamp) external view returns (uint256);

    /// @notice Determine the prior index of supply staked by a given timestamp
    /// @dev Timestamp must be <= current timestamp
    /// @param _timestamp The timestamp to get the index at
    /// @return Index of supply checkpoint
    function getPriorSupplyIndex(uint256 _timestamp) external view returns (uint256);

    /// @notice Get number of rewards tokens
    function rewardsListLength() external view returns (uint256);

    /// @notice Get the list of rewards tokens
    function getAllRewards() external view returns (address[] memory);

    /// @notice Calculate how much in rewards are earned for a specific token and voter
    /// @param _token   Address of token to fetch rewards of
    /// @param _user    Address of the user to check
    /// @return Amount of token earned in rewards
    function earned(address _token, address _user) external view returns (uint256);

    /// @notice Deposit an amount into the rewards contract to earn future rewards
    /// @dev Internal notation used as only callable internally by `voter`.
    /// @param _amount  Amount deposited for the user
    /// @param _user    Address of the user
    function _deposit(uint256 _amount, address _user) external;

    /// @notice Withdraw an amount from the rewards contract associated to a voter
    /// @dev Internal notation used as only callable internally by `voter`.
    /// @param _amount  Amount withdrawn for the user
    /// @param _user    Address of the user
    function _withdraw(uint256 _amount, address _user) external;

    /// @notice Claim the rewards earned by a voter for a given token
    /// @param _user  Address of the user
    /// @param _token Token to claim rewards of
    function getReward(address _user, address _token) external;

    /// @notice Claim the rewards earned by a voter for a given list of tokens
    /// @dev Utility to help batch reward claims.
    /// @param _user    Address of the user
    /// @param _tokens  Array of tokens to claim rewards of
    function getRewards(address _user, address[] calldata _tokens) external;

    /// @notice Add rewards for voters to earn
    /// @param _token    Address of token to reward
    /// @param _amount   Amount of token to transfer to rewards
    function notifyRewardAmount(address _token, uint256 _amount) external;

    /// @notice Add ETH rewards for voters to earn
    function notifyRewardAmountETH() external payable;

    /// @notice Set the DAO fee on rewards
    /// @param _daoFee  New DAO fee, expressed in basis points
    function setDaoFee(uint256 _daoFee) external;
}
