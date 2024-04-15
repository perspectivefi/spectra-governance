// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVoter {
    error AlreadyVotedOrDeposited();
    error DistributeWindow();
    error FeeTooHigh();
    error UserRestricted();
    error MaximumVotingNumberTooLow();
    error NonZeroVotes();
    error NotARegisteredPool();
    error NotApprovedOrOwner();
    error NotWhitelistedUser();
    error SameAddress();
    error SameValue();
    error TooManyPools();
    error UnequalLengths();
    error VoteAlreadyAuthorized();
    error VoteAlreadyBanned();
    error VoteUnauthorized();
    error VotingRewardsAlreadyDeployed();
    error VotingRewardsNotDeployed();
    error ZeroBalance();

    event VotingRewardsCreated(
        address indexed votingRewardsFactory,
        uint160 indexed poolId,
        address bribeVotingReward,
        address feesVotingReward,
        address creator
    );
    event Voted(
        address indexed voter,
        uint160 indexed poolId,
        address indexed user,
        uint256 weight,
        uint256 totalWeight,
        uint256 timestamp
    );
    event Abstained(
        address indexed voter,
        uint160 indexed poolId,
        address indexed user,
        uint256 weight,
        uint256 totalWeight,
        uint256 timestamp
    );
    event NotifyReward(address indexed sender, address indexed reward, uint256 amount);
    event VoteBanned(uint160 indexed poolId);
    event VoteReauthorized(uint160 indexed poolId);
    event WhitelistBribeToken(address indexed whitelister, address indexed token, bool indexed _bool);
    event WhitelistUser(address indexed whitelister, address indexed user, bool indexed _bool);
    event Approval(address indexed sender, address _operator, bool _approved);

    /// @notice Address of DAO
    function dao() external view returns (address);

    /// @notice Trusted forwarder address to pass into factories
    function forwarder() external view returns (address);

    /// @notice The ve token that governs these contracts
    function ve() external view returns (address);

    /// @notice Address of GovernanceRegistry
    function governanceRegistry() external view returns (address);

    /// @dev Total Voting Weight
    function totalWeight() external view returns (uint256);

    /// @dev Max number of pools one voter can vote for at once
    function maxVotingNum() external view returns (uint256);

    /// @dev Default share of fees voting rewards to be sent to the DAO, in basis points
    function defaultFeesRewardsDaoFee() external view returns (uint256);

    /// @dev Default share of bribe voting rewards to be sent to the DAO, in basis points
    function defaultBribeRewardsDaoFee() external view returns (uint256);

    /// @dev Pool => Fees and Bribes voting rewards deployment status
    function hasVotingRewards(uint160 _poolId) external view returns (bool);

    /// @dev Pool => Fees Voting Reward
    function poolToFees(uint160 _poolId) external view returns (address);

    /// @dev Pool => Bribes Voting Reward
    function poolToBribe(uint160 _poolId) external view returns (address);

    /// @dev Pool => Weights
    function weights(uint160 _poolId) external view returns (uint256);

    /// @dev User => Pool => Votes
    function votes(address _user, uint160 _poolId) external view returns (uint256);

    /// @dev User => Total voting weight
    function usedWeights(address _user) external view returns (uint256);

    /// @dev User => Timestamp of last vote (ensures single vote per epoch)
    function lastVoted(address _user) external view returns (uint256);

    /// @dev Token => Whitelisted status
    function isWhitelistedBribeToken(address token) external view returns (bool);

    /// @dev User => Whitelisted status
    function isWhitelistedUser(address _user) external view returns (bool);

    /// @dev User => Is voting authorized for pool
    function isVoteAuthorized(uint160 _poolId) external view returns (bool);

    /// @dev User => Is currently voting
    function voted(address _user) external view returns (bool);

    /// @dev User => Is restricted from voting
    function isRestrictedUser(address _user) external view returns (bool);

    /// @notice Number of pools with associated voting rewards
    function length() external view returns (uint256);

    /// @notice List of all poolIds for pools with associated voting rewards
    function getAllPoolIds() external view returns (uint160[] memory);

    /// @notice initialize list of whitelisted tokens
    function initialize(address[] calldata _tokens) external;

    /// @notice Called by users to vote for pools. Votes distributed proportionally based on weights.
    ///         Can only vote once per epoch.
    ///         Can only vote for registered pools with deployed voting rewards.
    /// @dev Weights are distributed proportional to the sum of the weights in the array.
    ///      Throws if length of _poolVote and _weights do not match.
    /// @param _user        Address of the user voting.
    /// @param _poolVote    Array of identifiers of pools that are voted for.
    /// @param _weights     Weights of pools.
    function vote(address _user, uint160[] calldata _poolVote, uint256[] calldata _weights) external;

    /// @notice Called by users to update voting balances in voting rewards contracts.
    /// @param _user Address of the user whose balance are to be updated.
    function poke(address _user) external;

    /// @notice Called by approved address to vote for multiple users for pools. For each user, votes are distributed proportionally based on weights.
    ///         Each user can only vote once per epoch.
    ///         Users can only vote for registered pools with deployed voting rewards.
    /// @dev Weights are distributed proportionally to the sum of the weights in the array.
    ///      Throws if length of _poolVote and _weights do not match.
    /// @param _users       Addresses of the users voting.
    /// @param _poolVote    Array of identifiers of pools that are voted for.
    /// @param _weights     Weights of pools.
    function batchVote(address[] calldata _users, uint160[] calldata _poolVote, uint256[] calldata _weights) external;

    /// @notice Called by approved address to update voting balances for multiple users in voting rewards contracts.
    /// @param _users Addresses of the users whose balance are to be updated.
    function batchPoke(address[] calldata _users) external;

    /// @notice Called by users to reset voting state.
    ///         Cannot reset in the same epoch that you voted in.
    ///         Can vote again after reset.
    /// @param _user Address of the user resetting.
    function reset(address _user) external;

    /// @notice Bulk claim bribes for a given user address.
    /// @dev Utility to help batch bribe claims.
    /// @param _bribes  Array of BribeVotingReward contracts to collect from.
    /// @param _tokens  Array of tokens that are used as bribes.
    /// @param _user    Address of the user to claim bribe rewards for.
    function claimBribes(address[] calldata _bribes, address[][] calldata _tokens, address _user) external;

    /// @notice Bulk claim fees for a given user address.
    /// @dev Utility to help batch fee claims.
    /// @param _fees    Array of FeesVotingReward contracts to collect from.
    /// @param _tokens  Array of tokens that are used as fees.
    /// @param _user    Address of the user to claim fees rewards for.
    function claimFees(address[] calldata _fees, address[][] calldata _tokens, address _user) external;

    /// @notice Bulk claim bribes and fees for a given user address.
    /// @dev Utility to help batch claims for bribe and fees associated to a given list of pools.
    /// @param _poolIds     Array of pool identifiers to collect associated bribes and fees from.
    /// @param _bribeTokens Array of tokens that are used as bribes.
    /// @param _feeTokens   Array of tokens that are used as fees.
    /// @param _user        Address of the user to claim rewards for.
    function claimPoolsVotingRewards(
        uint160[] calldata _poolIds,
        address[][] calldata _bribeTokens,
        address[][] calldata _feeTokens,
        address _user
    ) external;

    /// @notice Create voting rewards for a pool (unpermissioned).
    /// @dev Pool needs to be registered in governance registry.
    /// @param _poolId .
    function createVotingRewards(uint160 _poolId) external returns (address fees, address bribe);

    /// @notice Set maximum number of pools that can be voted for.
    /// @dev Throws if not called by governor.
    ///      Throws if _maxVotingNum is too low.
    ///      Throws if the values are the same.
    /// @param _maxVotingNum .
    function setMaxVotingNum(uint256 _maxVotingNum) external;

    /// @notice Set default share of fees voting rewards to be sent to the DAO.
    /// @dev Throws if not called by governor.
    ///      Throws if _defaultFeesRewardsDaoFee is too high.
    /// @param _defaultFeesRewardsDaoFee fee in basis points.
    function setDefaultFeesRewardsDaoFee(uint256 _defaultFeesRewardsDaoFee) external;

    /// @notice Set default share of bribe voting rewards to be sent to the DAO.
    /// @dev Throws if not called by governor.
    ///      Throws if _defaultBribeRewardsDaoFee is too high.
    /// @param _defaultBribeRewardsDaoFee fee in basis points.
    function setDefaultBribeRewardsDaoFee(uint256 _defaultBribeRewardsDaoFee) external;

    /// @notice Set for an array of pools the share of fees and bribe voting rewards to be sent to the DAO.
    /// @dev Throws if not called by governor.
    ///      Throws if _feesRewardsDaoFee or _bribeRewardsDaoFee is too high.
    /// @param _poolIds Array of pools to set fees and bribe voting rewards for.
    /// @param _feesRewardsDaoFee fees voting reward fee in basis points.
    /// @param _bribeRewardsDaoFee bribe voting reward fee in basis points.
    function setPoolsVotingRewardsDaoFee(
        uint160[] calldata _poolIds,
        uint256 _feesRewardsDaoFee,
        uint256 _bribeRewardsDaoFee
    ) external;

    /// @notice Set fees and bribe voting rewards.
    /// @dev Throws if not called by governor.
    ///      Throws if _feesRewardsDaoFee or _bribeRewardsDaoFee is too high.
    /// @param _fees Array of FeesVotingReward contracts to set fees voting rewards for.
    /// @param _feesRewardsDaoFee fees voting reward fee in basis points.
    /// @param _bribes Array of BribeVotingReward contracts to set bribe voting rewards for.
    /// @param _bribeRewardsDaoFee bribe voting reward fee in basis points.
    function setVotingRewardsDaoFee(
        address[] calldata _fees,
        uint256 _feesRewardsDaoFee,
        address[] calldata _bribes,
        uint256 _bribeRewardsDaoFee
    ) external;

    /// @notice Remove voting rights for user.
    /// @dev Throws if not called by governor.
    /// @param _user account to set voting rights for.
    function setRestrictedUser(address _user, bool _bool) external;

    /// @notice Whitelist (or unwhitelist) token for use in bribes.
    /// @dev Throws if not called by governor.
    /// @param _token .
    /// @param _bool .
    function whitelistBribeToken(address _token, bool _bool) external;

    /// @notice Whitelist (or unwhitelist) user address for voting in last hour prior to epoch flip.
    /// @dev Throws if not called by governor.
    ///      Throws if already whitelisted.
    /// @param _user .
    /// @param _bool .
    function whitelistUser(address _user, bool _bool) external;

    /// @notice Ban voting for a pool
    /// @dev Throws if pool does not have associated voting rewards deployed
    ///      Throws if voting is already banned for this pool
    /// @param _poolId .
    function banVote(uint160 _poolId) external;

    /// @notice Reauthorize voting for a pool
    /// @dev Throws if pool does not have associated voting rewards deployed
    ///      Throws if voting is already authorized for this pool
    /// @param _poolId .
    function reauthorizeVote(uint160 _poolId) external;

    // Delegation

    /// @notice Check wether _operator is owner or an approved operator for a given _user.
    /// @param _operator .
    /// @param _user .
    function isApprovedOrOwner(address _operator, address _user) external returns (bool);

    /// @notice Give or take back approval for an operator to manage voting and rewards claiming on behalf of sender.
    /// @param _operator .
    /// @param _approved True to approve operator, false otherwise.
    function setApprovalForAll(address _operator, bool _approved) external;
}
