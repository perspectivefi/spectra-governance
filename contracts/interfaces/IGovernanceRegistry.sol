// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGovernanceRegistry {
    /* STRUCTS
     *****************************************************************************************************************/
    struct PoolNetworkData {
        address poolAddress;
        uint256 chainId;
        bool isRegistered;
    }

    /* EVENTS
     *****************************************************************************************************************/
    event VotingRewardsFactoryChange(
        address indexed previousVotingRewardsFactory,
        address indexed newVotingRewardsFactory
    );
    event PoolRegistered(address indexed pool, uint256 indexed chainId, bool indexed isRegistered);

    /* GETTERS
     *****************************************************************************************************************/

    /// @notice Get the VotingReward factory.
    function votingRewardsFactory() external view returns (address);

    /// @notice Get the pool data.
    /// @param _poolId The pool ID
    /// @return The pool address
    /// @return The chainId of the network on which the pool is deployed
    /// @return Boolean value, true if the pool is registered
    function poolsData(uint160 _poolId) external view returns (address, uint256, bool);

    /// @notice Get the pool id for the given pool.
    /// @dev The pool ID is computed by XORing the pool address with the chainId of the network on which the pool is deployed.
    function getPoolId(address _pool, uint256 _chainId) external view returns (uint160);

    /// @notice Returns wether the pool is registered.
    /// @param _poolId The pool ID
    function isPoolRegistered(uint160 _poolId) external view returns (bool);

    /// @notice Returns wether the pool is registered.
    /// @param _pool The pool address
    /// @param _chainId The chainId of the network on which the pool is deployed
    function isPoolRegistered(address _pool, uint256 _chainId) external view returns (bool);

    /* SETTERS
     *****************************************************************************************************************/

    /// @notice Set the VotingReward factory.
    /// @param _votingRewardsFactory .
    function setVotingRewardsFactory(address _votingRewardsFactory) external;

    /// @notice Set the pool registration.
    /// @param _pool The pool address
    /// @param _chainId The chainId of the network on which the pool is deployed
    /// @param _isRegistered True if pool needs to be registered, false otherwise
    function setPoolRegistration(address _pool, uint256 _chainId, bool _isRegistered) external;

    /// @notice Set the registration for multiple pools.
    /// @dev Utility to batch pool registrations.
    /// @param _pools The array of pools
    /// @param _chainIds The chainIds of the respective networks on which each pool is deployed
    /// @param _isRegistered True if pool needs to be registered, false otherwise
    function setPoolsRegistration(address[] calldata _pools, uint256[] calldata _chainIds, bool _isRegistered) external;
}
