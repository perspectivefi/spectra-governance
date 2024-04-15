pragma solidity ^0.8.20;

/**
 * @title APW token contract interface
 * @notice Governance token of the APWine protocol
 */
interface IVotingEscrow {
    struct LockedBalance {
        int128 amount;
        uint256 end;
    }

    struct UserPoint {
        int128 bias;
        int128 slope; // # -dweight / dt
        uint256 ts;
        uint256 blk; // block
    }

    struct GlobalPoint {
        int128 bias;
        int128 slope; // # -dweight / dt
        uint256 ts;
        uint256 blk; // block
    }

    enum DepositType {
        DEPOSIT_FOR_TYPE,
        CREATE_LOCK_TYPE,
        INCREASE_LOCK_AMOUNT,
        INCREASE_UNLOCK_TIME
    }

    /// @notice Address of token (APW) used to create a lock
    function token() external view returns (address);

    /// @notice User -> lock amount and expiry
    function locked(address _addr) external view returns (LockedBalance memory);

    /// @notice Current epoch
    function epoch() external view returns (uint256);

    /// @notice Epoch -> unsigned point
    function point_history(uint256 _idx) external view returns (GlobalPoint memory);

    /// @notice User -> Epoch -> unsigned point
    function user_point_history(address _userAddr, uint256 _idx) external view returns (UserPoint memory);

    /// @notice User -> current epoch
    function user_point_epoch(address _addr) external view returns (uint256);

    /// @notice Time -> signed slope change
    function slope_changes(uint256 _idx) external view returns (int128);

    /// @notice Name of the token
    function name() external view returns (string memory);

    /// @notice Symbol of the token
    function version() external view returns (string memory);

    /// @notice Admin of the token
    function admin() external view returns (address);

    /// @notice Calculate total voting power at some point in the past
    /// @param _block Block to calculate the total voting power at
    /// @return Total voting power at `_block`
    function totalSupplyAt(uint256 _block) external view returns (uint256);

    /// @notice Measure voting power of `_addr`
    function balanceOf(address _addr) external view returns (uint256);

    /// @notice Measure voting power of `_addr` at block height `_block`
    /// @dev Adheres to MiniMe `balanceOfAt` interface: https://github.com/Giveth/minime
    /// @param _addr User's wallet address
    /// @param _block Block to calculate the voting power at
    /// @return Voting power
    function balanceOfAt(address _addr, uint256 _block) external view returns (uint256);

    /// @notice Get the timestamp for checkpoint `_idx` for `_addr`
    /// @param _addr User wallet address
    /// @param _idx User epoch number
    /// @return Epoch time of the checkpoint
    function user_point_history__ts(address _addr, uint256 _idx) external view returns (uint256);

    /// @notice Deposit `_value` tokens for `_addr` and add to the lock
    /// @dev Anyone (even a smart contract) can deposit for someone else, but
    /// cannot extend their locktime and deposit for a brand new user
    /// @param _addr User's wallet address
    /// @param _value Amount to add to user's lock
    function deposit_for(address _addr, uint256 _value) external;

    /// @notice Get timestamp when `_addr`'s lock finishes
    /// @param _addr User wallet
    /// @return Epoch time of the lock end
    function locked__end(address _addr) external returns (uint256);

    /// @notice Deposit `_value` additional tokens for `msg.sender`
    /// without modifying the unlock time
    /// @param _value Amount of tokens to deposit and add to the lock
    function increase_amount(uint256 _value) external;

    /// @notice Extend the unlock time for `msg.sender` to `_unlock_time`
    /// @param _unlock_time New epoch time for unlocking
    function increase_unlock_time(uint256 _unlock_time) external;

    /// @notice Deposit `_value` tokens for `msg.sender` and lock until `_unlock_time`
    /// @param _value Amount to deposit
    /// @param _unlock_time Epoch time when tokens unlock, rounded down to whole weeks
    function create_lock(uint256 _value, uint256 _unlock_time) external;

    /// @notice Withdraw all tokens for `msg.sender`
    /// @dev Only possible if the lock has expired
    function withdraw() external;
}
