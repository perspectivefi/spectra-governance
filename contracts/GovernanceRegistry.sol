// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {IGovernanceRegistry} from "./interfaces/IGovernanceRegistry.sol";

/// @title Spectra Factory Registry
/// @author Spectra.finance
/// @notice Spectra Governance registry to store
contract GovernanceRegistry is IGovernanceRegistry, AccessManaged {
    /// @inheritdoc IGovernanceRegistry
    address public votingRewardsFactory;
    /// @inheritdoc IGovernanceRegistry
    mapping(uint160 => PoolNetworkData) public poolsData;

    constructor(address _initialAuthority) AccessManaged(_initialAuthority) {}

    /* GETTERS
     *****************************************************************************************************************/

    /// @inheritdoc IGovernanceRegistry
    function getPoolId(address _pool, uint256 _chainId) public pure override returns (uint160) {
        return uint160(_pool) ^ uint160(_chainId);
    }

    /// @inheritdoc IGovernanceRegistry
    function isPoolRegistered(uint160 _poolId) external view override returns (bool) {
        return poolsData[_poolId].isRegistered;
    }

    /// @inheritdoc IGovernanceRegistry
    function isPoolRegistered(address _pool, uint256 _chainId) external view override returns (bool) {
        return poolsData[getPoolId(_pool, _chainId)].isRegistered;
    }

    /* SETTERS
     *****************************************************************************************************************/

    /// @inheritdoc IGovernanceRegistry
    function setVotingRewardsFactory(address _votingRewardsFactory) external override restricted {
        emit VotingRewardsFactoryChange(votingRewardsFactory, _votingRewardsFactory);
        votingRewardsFactory = _votingRewardsFactory;
    }

    /// @inheritdoc IGovernanceRegistry
    function setPoolRegistration(address _pool, uint256 _chainId, bool _isRegistered) public override restricted {
        uint160 _poolId = getPoolId(_pool, _chainId);
        emit PoolRegistered(_pool, _chainId, _isRegistered);
        poolsData[_poolId] = PoolNetworkData({poolAddress: _pool, chainId: _chainId, isRegistered: _isRegistered});
    }

    /// @inheritdoc IGovernanceRegistry
    function setPoolsRegistration(
        address[] calldata _pools,
        uint256[] calldata _chainIds,
        bool _isRegistered
    ) external override restricted {
        uint256 _length = _pools.length;
        for (uint256 i = 0; i < _length; ++i) {
            setPoolRegistration(_pools[i], _chainIds[i], _isRegistered);
        }
    }
}
