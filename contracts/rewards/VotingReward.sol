// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessManaged, Context} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IVotingReward} from "../interfaces/IVotingReward.sol";
import {IVoter} from "../interfaces/IVoter.sol";
import {VelodromeTimeLibrary} from "../libraries/VelodromeTimeLibrary.sol";

/// @title Voting Reward
/// @author velodrome.finance, spectra.finance
/// @notice Base voting reward contract for distribution of rewards by user address on a weekly basis
abstract contract VotingReward is IVotingReward, AccessManaged, ERC2771Context, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @inheritdoc IVotingReward
    uint256 public constant DURATION = 7 days;

    uint256 public constant FEE_DIVISOR = 10000;

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @inheritdoc IVotingReward
    address public immutable dao;
    /// @inheritdoc IVotingReward
    address public immutable voter;
    /// @inheritdoc IVotingReward
    uint160 public immutable poolId;

    /// @inheritdoc IVotingReward
    uint256 public totalSupply;
    /// @inheritdoc IVotingReward
    mapping(address => uint256) public balanceOf;
    /// @inheritdoc IVotingReward
    mapping(address => mapping(uint256 => uint256)) public tokenRewardsPerEpoch;
    /// @inheritdoc IVotingReward
    mapping(address => mapping(address => uint256)) public lastEarn;

    /// @dev all rewards tokens
    address[] public rewards;
    /// @inheritdoc IVotingReward
    mapping(address => bool) public isReward;
    /// @inheritdoc IVotingReward
    uint256 public daoFee;

    /// @notice A record of balance checkpoints for each account, by index
    mapping(address => mapping(uint256 => Checkpoint)) public checkpoints;
    /// @inheritdoc IVotingReward
    mapping(address => uint256) public numCheckpoints;
    /// @notice A record of balance checkpoints for each token, by index
    mapping(uint256 => SupplyCheckpoint) public supplyCheckpoints;
    /// @inheritdoc IVotingReward
    uint256 public supplyNumCheckpoints;

    constructor(
        uint160 _poolId,
        address _dao,
        address _initialAuthority,
        address _forwarder,
        address _voter,
        address _initialRewardToken,
        uint256 _daoFee
    ) AccessManaged(_initialAuthority) ERC2771Context(_forwarder) {
        poolId = _poolId;
        voter = _voter;
        dao = _dao;
        if (_daoFee > FEE_DIVISOR) revert FeeTooHigh();
        daoFee = _daoFee;

        if (_initialRewardToken != address(0)) {
            isReward[_initialRewardToken] = true;
            rewards.push(_initialRewardToken);
        }
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

    /// @inheritdoc IVotingReward
    function getPriorBalanceIndex(address _user, uint256 _timestamp) public view returns (uint256) {
        uint256 nCheckpoints = numCheckpoints[_user];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[_user][nCheckpoints - 1].timestamp <= _timestamp) {
            return (nCheckpoints - 1);
        }

        // Next check implicit zero balance
        if (checkpoints[_user][0].timestamp > _timestamp) {
            return 0;
        }

        uint256 lower = 0;
        uint256 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[_user][center];
            if (cp.timestamp == _timestamp) {
                return center;
            } else if (cp.timestamp < _timestamp) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return lower;
    }

    /// @inheritdoc IVotingReward
    function getPriorSupplyIndex(uint256 _timestamp) public view returns (uint256) {
        uint256 nCheckpoints = supplyNumCheckpoints;
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (supplyCheckpoints[nCheckpoints - 1].timestamp <= _timestamp) {
            return (nCheckpoints - 1);
        }

        // Next check implicit zero balance
        if (supplyCheckpoints[0].timestamp > _timestamp) {
            return 0;
        }

        uint256 lower = 0;
        uint256 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            SupplyCheckpoint memory cp = supplyCheckpoints[center];
            if (cp.timestamp == _timestamp) {
                return center;
            } else if (cp.timestamp < _timestamp) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return lower;
    }

    function _writeCheckpoint(address _user, uint256 _balance) internal {
        uint256 _nCheckPoints = numCheckpoints[_user];
        uint256 _timestamp = block.timestamp;

        if (
            _nCheckPoints > 0 &&
            VelodromeTimeLibrary.epochStart(checkpoints[_user][_nCheckPoints - 1].timestamp) ==
            VelodromeTimeLibrary.epochStart(_timestamp)
        ) {
            checkpoints[_user][_nCheckPoints - 1] = Checkpoint(_timestamp, _balance);
        } else {
            checkpoints[_user][_nCheckPoints] = Checkpoint(_timestamp, _balance);
            numCheckpoints[_user] = _nCheckPoints + 1;
        }
    }

    function _writeSupplyCheckpoint() internal {
        uint256 _nCheckPoints = supplyNumCheckpoints;
        uint256 _timestamp = block.timestamp;

        if (
            _nCheckPoints > 0 &&
            VelodromeTimeLibrary.epochStart(supplyCheckpoints[_nCheckPoints - 1].timestamp) ==
            VelodromeTimeLibrary.epochStart(_timestamp)
        ) {
            supplyCheckpoints[_nCheckPoints - 1] = SupplyCheckpoint(_timestamp, totalSupply);
        } else {
            supplyCheckpoints[_nCheckPoints] = SupplyCheckpoint(_timestamp, totalSupply);
            supplyNumCheckpoints = _nCheckPoints + 1;
        }
    }

    /// @inheritdoc IVotingReward
    function rewardsListLength() external view returns (uint256) {
        return rewards.length;
    }

    /// @inheritdoc IVotingReward
    function getAllRewards() external view returns (address[] memory) {
        return rewards;
    }

    /// @inheritdoc IVotingReward
    function earned(address _token, address _user) public view returns (uint256) {
        if (numCheckpoints[_user] == 0) {
            return 0;
        }

        uint256 reward = 0;
        uint256 _supply = 1;
        uint256 _currTs = VelodromeTimeLibrary.epochStart(lastEarn[_token][_user]); // take epoch last claimed in as starting point
        uint256 _index = getPriorBalanceIndex(_user, _currTs);
        Checkpoint memory cp0 = checkpoints[_user][_index];

        // accounts for case where lastEarn is before first checkpoint
        _currTs = Math.max(_currTs, VelodromeTimeLibrary.epochStart(cp0.timestamp));

        // get epochs between current epoch and first checkpoint in same epoch as last claim
        uint256 numEpochs = (VelodromeTimeLibrary.epochStart(block.timestamp) - _currTs) / DURATION;

        if (numEpochs > 0) {
            for (uint256 i = 0; i < numEpochs; i++) {
                // get index of last checkpoint in this epoch
                _index = getPriorBalanceIndex(_user, _currTs + DURATION - 1);
                // get checkpoint in this epoch
                cp0 = checkpoints[_user][_index];
                // get supply of last checkpoint in this epoch
                _supply = Math.max(supplyCheckpoints[getPriorSupplyIndex(_currTs + DURATION - 1)].supply, 1);
                reward += (cp0.balanceOf * tokenRewardsPerEpoch[_token][_currTs]) / _supply;
                _currTs += DURATION;
            }
        }

        return reward;
    }

    /// @inheritdoc IVotingReward
    function _deposit(uint256 _amount, address _user) external restricted {
        totalSupply += _amount;
        balanceOf[_user] += _amount;

        _writeCheckpoint(_user, balanceOf[_user]);
        _writeSupplyCheckpoint();

        emit Deposit(_msgSender(), _user, _amount);
    }

    /// @inheritdoc IVotingReward
    function _withdraw(uint256 _amount, address _user) external restricted {
        totalSupply -= _amount;
        balanceOf[_user] -= _amount;

        _writeCheckpoint(_user, balanceOf[_user]);
        _writeSupplyCheckpoint();

        emit Withdraw(_msgSender(), _user, _amount);
    }

    /// @inheritdoc IVotingReward
    function getReward(address _user, address _token) external override nonReentrant {
        address sender = _msgSender();
        if (!IVoter(voter).isApprovedOrOwner(sender, _user)) {
            // access restriction
            _checkCanCall(sender, _msgData());
        }

        _getReward(_user, _token);
    }

    /// @inheritdoc IVotingReward
    function getRewards(address _user, address[] calldata _tokens) external override nonReentrant {
        address sender = _msgSender();
        if (!IVoter(voter).isApprovedOrOwner(sender, _user)) {
            // access restriction
            _checkCanCall(sender, _msgData());
        }

        uint256 _length = _tokens.length;
        for (uint256 i = 0; i < _length; i++) {
            _getReward(_user, _tokens[i]);
        }
    }

    /// @dev used with all getReward implementations
    function _getReward(address _user, address _token) internal {
        uint256 _reward = earned(_token, _user);
        lastEarn[_token][_user] = block.timestamp;
        if (_reward > 0) {
            if (_token == ETH) {
                payable(_user).transfer(_reward);
            } else {
                IERC20(_token).safeTransfer(_user, _reward);
            }
            emit ClaimRewards(_user, _token, _reward);
        }
    }

    /// @inheritdoc IVotingReward
    function notifyRewardAmount(address _token, uint256 _amount) external virtual nonReentrant {}

    /// @inheritdoc IVotingReward
    function notifyRewardAmountETH() external payable virtual nonReentrant {}

    /// @dev used within all notifyRewardAmount implementations
    function _notifyRewardAmount(address _sender, address _token, uint256 _amount) internal {
        if (_amount == 0) revert ZeroAmount();

        if (_token != ETH) {
            IERC20(_token).safeTransferFrom(_sender, address(this), _amount);
        }

        uint256 epochStart = VelodromeTimeLibrary.epochStart(block.timestamp);
        if (daoFee != 0) {
            uint256 _fee = (_amount * daoFee) / FEE_DIVISOR;
            if (_token == ETH) {
                payable(dao).transfer(_fee);
            } else {
                IERC20(_token).safeTransfer(dao, _fee);
            }
            tokenRewardsPerEpoch[_token][epochStart] += _amount - _fee;
        } else {
            tokenRewardsPerEpoch[_token][epochStart] += _amount;
        }

        emit NotifyReward(_sender, _token, epochStart, _amount);
    }

    /// @inheritdoc IVotingReward
    function setDaoFee(uint256 _daoFee) external restricted {
        if (_daoFee > FEE_DIVISOR) revert FeeTooHigh();

        emit DaoFeeChange(_daoFee, daoFee);
        daoFee = _daoFee;
    }
}
