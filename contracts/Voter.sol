// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AccessManaged, IAccessManager, Context} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {VelodromeTimeLibrary} from "./libraries/VelodromeTimeLibrary.sol";
import {IVotingRewardsFactory} from "./interfaces/factories/IVotingRewardsFactory.sol";
import {IVotingReward} from "./interfaces/IVotingReward.sol";
import {IVoter} from "./interfaces/IVoter.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {IGovernanceRegistry} from "./interfaces/IGovernanceRegistry.sol";

/// @title Voter
/// @notice Manage votes, emission distribution, and voting rewards creation within the Spectra ecosystem.
contract Voter is IVoter, AccessManaged, ERC2771Context, ReentrancyGuard {
    /// @inheritdoc IVoter
    address public immutable dao;
    /// @inheritdoc IVoter
    address public immutable forwarder;
    /// @inheritdoc IVoter
    address public immutable ve;
    /// @inheritdoc IVoter
    address public immutable governanceRegistry;
    /// @notice Rewards are released over 7 days
    uint256 internal constant DURATION = 7 days;

    /// @inheritdoc IVoter
    uint256 public totalWeight;
    /// @inheritdoc IVoter
    uint256 public maxVotingNum;
    /// @notice minimum value for maxVotingNum
    uint256 internal constant MIN_MAXVOTINGNUM = 10;

    /// @inheritdoc IVoter
    uint256 public defaultFeesRewardsDaoFee;
    /// @inheritdoc IVoter
    uint256 public defaultBribeRewardsDaoFee;
    /// @notice equivalent to 100% fee
    uint256 internal constant MAX_DEFAULT_FEE = 10000;

    /// @dev All pools eligible for incentives
    uint160[] public poolIds;
    /// @inheritdoc IVoter
    mapping(uint160 => bool) public hasVotingRewards;
    /// @inheritdoc IVoter
    mapping(uint160 => address) public poolToFees;
    /// @inheritdoc IVoter
    mapping(uint160 => address) public poolToBribe;
    /// @inheritdoc IVoter
    mapping(uint160 => uint256) public weights;
    /// @inheritdoc IVoter
    mapping(address => mapping(uint160 => uint256)) public votes;
    /// @dev List of pools voted for by user
    mapping(address => uint160[]) public poolVote;
    /// @inheritdoc IVoter
    mapping(address => uint256) public usedWeights;
    /// @inheritdoc IVoter
    mapping(address => uint256) public lastVoted;
    /// @inheritdoc IVoter
    mapping(address => bool) public isWhitelistedBribeToken;
    /// @inheritdoc IVoter
    mapping(address => bool) public isWhitelistedUser;
    /// @inheritdoc IVoter
    mapping(uint160 => bool) public isVoteAuthorized;
    /// @inheritdoc IVoter
    mapping(address => bool) public voted;
    /// @inheritdoc IVoter
    mapping(address => bool) public isRestrictedUser;

    constructor(
        address _dao,
        address _initialAuthority,
        address _forwarder,
        address _ve,
        address _governanceRegistry,
        uint256 _defaultFeesRewardsDaoFee,
        uint256 _defaultBribeRewardsDaoFee
    ) AccessManaged(_initialAuthority) ERC2771Context(_forwarder) {
        dao = _dao;
        forwarder = _forwarder;
        ve = _ve;
        governanceRegistry = _governanceRegistry;
        maxVotingNum = 30;
        if (_defaultFeesRewardsDaoFee > 10000 || _defaultBribeRewardsDaoFee > 10000) revert FeeTooHigh();
        defaultFeesRewardsDaoFee = _defaultFeesRewardsDaoFee;
        defaultBribeRewardsDaoFee = _defaultBribeRewardsDaoFee;
    }

    modifier onlyNewEpoch(address _user) {
        // ensure new epoch since last vote
        if (VelodromeTimeLibrary.epochStart(block.timestamp) <= lastVoted[_user]) {
            revert AlreadyVotedOrDeposited();
        }
        if (block.timestamp <= VelodromeTimeLibrary.epochVoteStart(block.timestamp)) revert DistributeWindow();
        _;
    }

    function _msgData() internal view override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    function _msgSender() internal view override(Context, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    function _contextSuffixLength() internal view override(Context, ERC2771Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }

    function epochStart(uint256 _timestamp) external pure returns (uint256) {
        return VelodromeTimeLibrary.epochStart(_timestamp);
    }

    function epochNext(uint256 _timestamp) external pure returns (uint256) {
        return VelodromeTimeLibrary.epochNext(_timestamp);
    }

    function epochVoteStart(uint256 _timestamp) external pure returns (uint256) {
        return VelodromeTimeLibrary.epochVoteStart(_timestamp);
    }

    function epochVoteEnd(uint256 _timestamp) external pure returns (uint256) {
        return VelodromeTimeLibrary.epochVoteEnd(_timestamp);
    }

    function initialize(address[] calldata _tokens) external restricted {
        uint256 _length = _tokens.length;
        for (uint256 i = 0; i < _length; i++) {
            _whitelistBribeToken(_tokens[i], true);
        }
    }

    /// @inheritdoc IVoter
    function setMaxVotingNum(uint256 _maxVotingNum) external restricted {
        if (_maxVotingNum < MIN_MAXVOTINGNUM) revert MaximumVotingNumberTooLow();
        if (_maxVotingNum == maxVotingNum) revert SameValue();
        maxVotingNum = _maxVotingNum;
    }

    /// @inheritdoc IVoter
    function setDefaultFeesRewardsDaoFee(uint256 _defaultFeesRewardsDaoFee) external restricted {
        if (_defaultFeesRewardsDaoFee > MAX_DEFAULT_FEE) {
            revert FeeTooHigh();
        }
        defaultFeesRewardsDaoFee = _defaultFeesRewardsDaoFee;
    }

    /// @inheritdoc IVoter
    function setDefaultBribeRewardsDaoFee(uint256 _defaultBribeRewardsDaoFee) external restricted {
        if (_defaultBribeRewardsDaoFee > MAX_DEFAULT_FEE) revert FeeTooHigh();
        defaultBribeRewardsDaoFee = _defaultBribeRewardsDaoFee;
    }

    /// @inheritdoc IVoter
    function setPoolsVotingRewardsDaoFee(
        uint160[] calldata _poolIds,
        uint256 _feesRewardsDaoFee,
        uint256 _bribeRewardsDaoFee
    ) external restricted {
        uint256 _length = _poolIds.length;
        for (uint256 i = 0; i < _length; i++) {
            uint160 _poolId = _poolIds[i];
            if (!hasVotingRewards[_poolId]) revert VotingRewardsNotDeployed();
            IVotingReward(poolToFees[_poolId]).setDaoFee(_feesRewardsDaoFee);
            IVotingReward(poolToBribe[_poolId]).setDaoFee(_bribeRewardsDaoFee);
        }
    }

    /// @inheritdoc IVoter
    function setVotingRewardsDaoFee(
        address[] calldata _fees,
        uint256 _feesRewardsDaoFee,
        address[] calldata _bribes,
        uint256 _bribeRewardsDaoFee
    ) external restricted {
        uint256 _length = _fees.length;
        for (uint256 i = 0; i < _length; i++) {
            IVotingReward(_fees[i]).setDaoFee(_feesRewardsDaoFee);
        }
        _length = _bribes.length;
        for (uint256 i = 0; i < _length; i++) {
            IVotingReward(_bribes[i]).setDaoFee(_bribeRewardsDaoFee);
        }
    }

    /// @inheritdoc IVoter
    function setRestrictedUser(address _user, bool _bool) external restricted {
        isRestrictedUser[_user] = _bool;
    }

    // function moved from the VotingEscrow to the Voter contract
    function _voting(address _user, bool _voted) internal {
        voted[_user] = _voted;
    }

    /// @inheritdoc IVoter
    function reset(address _user) external onlyNewEpoch(_user) nonReentrant {
        if (!isApprovedOrOwner(msg.sender, _user)) revert NotApprovedOrOwner();
        _reset(_user);
    }

    function _reset(address _user) internal {
        uint160[] memory _poolVote = poolVote[_user];
        uint256 _poolVoteCnt = _poolVote.length;
        uint256 _totalWeight = 0;

        for (uint256 i = 0; i < _poolVoteCnt; i++) {
            uint160 _poolId = _poolVote[i];
            uint256 _votes = votes[_user][_poolId];

            if (_votes != 0) {
                weights[_poolId] -= _votes;
                delete votes[_user][_poolId];
                IVotingReward(poolToFees[_poolId])._withdraw(_votes, _user);
                IVotingReward(poolToBribe[_poolId])._withdraw(_votes, _user);
                _totalWeight += _votes;
                emit Abstained(_msgSender(), _poolId, _user, _votes, weights[_poolId], block.timestamp);
            }
        }
        _voting(_user, false);
        totalWeight -= _totalWeight;
        usedWeights[_user] = 0;
        delete poolVote[_user];
    }

    function _poke(address _user, uint256 _weight) internal {
        uint160[] memory _poolVote = poolVote[_user];
        uint256 _poolCnt = _poolVote.length;
        uint256[] memory _weights = new uint256[](_poolCnt);

        for (uint256 i = 0; i < _poolCnt; i++) {
            _weights[i] = votes[_user][_poolVote[i]];
        }
        _vote(_user, _weight, _poolVote, _weights);
    }

    function _vote(address _user, uint256 _weight, uint160[] memory _poolVote, uint256[] memory _weights) internal {
        _reset(_user);
        uint256 _poolCnt = _poolVote.length;
        uint256 _totalVoteWeight = 0;
        uint256 _usedWeight = 0;

        for (uint256 i = 0; i < _poolCnt; i++) {
            _totalVoteWeight += _weights[i];
        }

        for (uint256 i = 0; i < _poolCnt; i++) {
            uint160 _poolId = _poolVote[i];
            if (!hasVotingRewards[_poolId]) revert VotingRewardsNotDeployed();
            if (!isVoteAuthorized[_poolId]) revert VoteUnauthorized();

            uint256 _poolWeight = (_weights[i] * _weight) / _totalVoteWeight;
            if (votes[_user][_poolId] != 0) revert NonZeroVotes();
            if (_poolWeight == 0) revert ZeroBalance();

            poolVote[_user].push(_poolId);

            weights[_poolId] += _poolWeight;
            votes[_user][_poolId] += _poolWeight;
            IVotingReward(poolToFees[_poolId])._deposit(_poolWeight, _user);
            IVotingReward(poolToBribe[_poolId])._deposit(_poolWeight, _user);
            _usedWeight += _poolWeight;
            emit Voted(_msgSender(), _poolId, _user, _poolWeight, weights[_poolId], block.timestamp);
        }
        if (_usedWeight > 0) _voting(_user, true);
        totalWeight += _usedWeight;
        usedWeights[_user] = _usedWeight;
    }

    /// @inheritdoc IVoter
    function poke(address _user) external nonReentrant {
        if (block.timestamp <= VelodromeTimeLibrary.epochVoteStart(block.timestamp)) revert DistributeWindow();
        uint256 _weight = IVotingEscrow(ve).balanceOf(_user);
        _poke(_user, _weight);
    }

    /// @inheritdoc IVoter
    function vote(
        address _user,
        uint160[] calldata _poolVote,
        uint256[] calldata _weights
    ) external onlyNewEpoch(_user) nonReentrant {
        if (!isApprovedOrOwner(_msgSender(), _user)) revert NotApprovedOrOwner();
        if (_poolVote.length != _weights.length) revert UnequalLengths();
        if (_poolVote.length > maxVotingNum) revert TooManyPools();
        if (isRestrictedUser[_user]) revert UserRestricted();
        uint256 _timestamp = block.timestamp;
        if ((_timestamp > VelodromeTimeLibrary.epochVoteEnd(_timestamp)) && !isWhitelistedUser[_user]) {
            revert NotWhitelistedUser();
        }
        lastVoted[_user] = _timestamp;
        uint256 _weight = IVotingEscrow(ve).balanceOf(_user);
        _vote(_user, _weight, _poolVote, _weights);
    }

    /// @inheritdoc IVoter
    function batchPoke(address[] calldata _users) external nonReentrant {
        if (block.timestamp <= VelodromeTimeLibrary.epochVoteStart(block.timestamp)) revert DistributeWindow();
        uint256 _length = _users.length;
        for (uint256 i = 0; i < _length; i++) {
            uint256 _weight = IVotingEscrow(ve).balanceOf(_users[i]);
            _poke(_users[i], _weight);
        }
    }

    /// @inheritdoc IVoter
    function batchVote(
        address[] calldata _users,
        uint160[] calldata _poolVote,
        uint256[] calldata _weights
    ) external nonReentrant {
        uint256 _timestamp = block.timestamp;
        if (_timestamp <= VelodromeTimeLibrary.epochVoteStart(_timestamp)) revert DistributeWindow();
        if (_poolVote.length != _weights.length) revert UnequalLengths();
        if (_poolVote.length > maxVotingNum) revert TooManyPools();
        uint256 _length = _users.length;
        for (uint256 i = 0; i < _length; i++) {
            if (VelodromeTimeLibrary.epochStart(_timestamp) <= lastVoted[_users[i]]) {
                revert AlreadyVotedOrDeposited();
            }
            if ((_timestamp > VelodromeTimeLibrary.epochVoteEnd(_timestamp)) && !isWhitelistedUser[_users[i]]) {
                revert NotWhitelistedUser();
            }
            if (!isApprovedOrOwner(_msgSender(), _users[i])) revert NotApprovedOrOwner();
            if (isRestrictedUser[_users[i]]) revert UserRestricted();
            lastVoted[_users[i]] = _timestamp;
            uint256 _weight = IVotingEscrow(ve).balanceOf(_users[i]);
            _vote(_users[i], _weight, _poolVote, _weights);
        }
    }

    /// @inheritdoc IVoter
    function whitelistBribeToken(address _token, bool _bool) external restricted {
        _whitelistBribeToken(_token, _bool);
    }

    function _whitelistBribeToken(address _token, bool _bool) internal {
        isWhitelistedBribeToken[_token] = _bool;
        emit WhitelistBribeToken(_msgSender(), _token, _bool);
    }

    /// @inheritdoc IVoter
    function whitelistUser(address _user, bool _bool) external restricted {
        isWhitelistedUser[_user] = _bool;
        emit WhitelistUser(_msgSender(), _user, _bool);
    }

    /// @inheritdoc IVoter
    function createVotingRewards(uint160 _poolId) external nonReentrant returns (address fees, address bribe) {
        if (hasVotingRewards[_poolId]) {
            revert VotingRewardsAlreadyDeployed();
        }
        if (!IGovernanceRegistry(governanceRegistry).isPoolRegistered(_poolId)) {
            revert NotARegisteredPool();
        }

        address votingRewardsFactory = IGovernanceRegistry(governanceRegistry).votingRewardsFactory();
        address accessManager = authority();

        (fees, bribe) = IVotingRewardsFactory(votingRewardsFactory).createRewards(
            _poolId,
            dao,
            accessManager,
            forwarder,
            address(0),
            defaultFeesRewardsDaoFee,
            defaultBribeRewardsDaoFee
        );

        poolToFees[_poolId] = fees;
        poolToBribe[_poolId] = bribe;
        hasVotingRewards[_poolId] = true;
        isVoteAuthorized[_poolId] = true;
        poolIds.push(_poolId);

        emit VotingRewardsCreated(votingRewardsFactory, _poolId, bribe, fees, _msgSender());
    }

    /// @inheritdoc IVoter
    function banVote(uint160 _poolId) external restricted {
        if (!hasVotingRewards[_poolId]) revert VotingRewardsNotDeployed();
        if (!isVoteAuthorized[_poolId]) revert VoteAlreadyBanned();
        isVoteAuthorized[_poolId] = false;
        emit VoteBanned(_poolId);
    }

    /// @inheritdoc IVoter
    function reauthorizeVote(uint160 _poolId) external restricted {
        if (!hasVotingRewards[_poolId]) revert VotingRewardsNotDeployed();
        if (isVoteAuthorized[_poolId]) revert VoteAlreadyAuthorized();
        isVoteAuthorized[_poolId] = true;
        emit VoteReauthorized(_poolId);
    }

    /// @inheritdoc IVoter
    function length() external view returns (uint256) {
        return poolIds.length;
    }

    /// @inheritdoc IVoter
    function getAllPoolIds() external view returns (uint160[] memory) {
        return poolIds;
    }

    /// @inheritdoc IVoter
    function claimBribes(address[] calldata _bribes, address[][] calldata _tokens, address _user) external {
        if (!isApprovedOrOwner(_msgSender(), _user)) revert NotApprovedOrOwner();
        uint256 _length = _bribes.length;
        for (uint256 i = 0; i < _length; i++) {
            IVotingReward(_bribes[i]).getRewards(_user, _tokens[i]);
        }
    }

    /// @inheritdoc IVoter
    function claimFees(address[] calldata _fees, address[][] calldata _tokens, address _user) external {
        if (!isApprovedOrOwner(_msgSender(), _user)) revert NotApprovedOrOwner();
        uint256 _length = _fees.length;
        for (uint256 i = 0; i < _length; i++) {
            IVotingReward(_fees[i]).getRewards(_user, _tokens[i]);
        }
    }

    /// @inheritdoc IVoter
    function claimPoolsVotingRewards(
        uint160[] calldata _poolIds,
        address[][] calldata _bribeTokens,
        address[][] calldata _feeTokens,
        address _user
    ) external {
        if (!isApprovedOrOwner(_msgSender(), _user)) revert NotApprovedOrOwner();
        uint256 _length = _poolIds.length;
        for (uint256 i = 0; i < _length; i++) {
            IVotingReward(poolToBribe[_poolIds[i]]).getRewards(_user, _bribeTokens[i]);
            IVotingReward(poolToFees[_poolIds[i]]).getRewards(_user, _feeTokens[i]);
        }
    }

    //////////////////////////////////////////////////////////////*/

    // Delegation:
    // Let another address execute the functions available in Voter

    /// @dev Mapping from owner address to mapping of operator addresses.
    mapping(address => mapping(address => bool)) internal ownerToOperators;

    /// @inheritdoc IVoter
    function isApprovedOrOwner(address _operator, address _user) public view returns (bool) {
        bool spenderIsOwner = _user == _operator;
        bool spenderIsApproved = ownerToOperators[_user][_operator];
        return spenderIsOwner || spenderIsApproved;
    }

    /// @inheritdoc IVoter
    function setApprovalForAll(address _operator, bool _approved) external {
        address sender = _msgSender();
        // Throws if `_operator` is the `_msgSender()`
        if (_operator == sender) revert SameAddress();
        ownerToOperators[sender][_operator] = _approved;
        emit Approval(sender, _operator, _approved);
    }
}
