# Spectra Access Control

## User Roles and Abilities

### Anyone
- Can provide liquidity.
- Can create a veAPW lock.
- Can deposit APW into their existing lock.
- Can bribe a liquidity pool through its linked BribeVotingRewards contract, provided that the chosen bribe token is whitelisted.
- Can trigger the distribution of APW rebases at the start of an epoch.
- Can create voting rewards for a liquidity pool if the pool is registered in the Registry and is not already created.

### veAPW Hodler
- For a detailed breakdown refer to [VOTINGESCROW.md](https://github.com/perspectivefi/tokenomics_update/blob/main/VOTINGESCROW.md)
- Can increase amount locked
- Can vote weekly on pool(s)
    - Earns bribes and trading fees
    - Earns weekly distribution of APW rebases
- Can withdraw veAPW if their lock is expired
- Can increase the lock time


## Admin Roles and Abilities

### Spectra DAO
 Multisig at [0xDbbfc051D200438dd5847b093B22484B842de9E7](https://etherscan.io/address/0xDbbfc051D200438dd5847b093B22484B842de9E7)
- Threshold: 1

### EmergencyCouncil
 Multisig at [0xDbbfc051D200438dd5847b093B22484B842de9E7](https://etherscan.io/address/0xDbbfc051D200438dd5847b093B22484B842de9E7)
- Threshold: 1


## Permissions List
This is an exhaustive list of all role permissions in Spectra governance, sorted by contracts. These roles must be assigned to respective contracts at deployment.

#### [VotingRewardsFactory](https://etherscan.io/address/0x0000000000000000000000000000000000000000#code)
- `ADMIN_ROLE` (roleId `0`)
    - Can set the roles required to call functions of deployed `VotingReward` contracts.

#### [GovernanceRegistry](https://etherscan.io/address/0x0000000000000000000000000000000000000000#code)
- `REGISTRY_ROLE` (roleId `4`)
    - Can set address of VotingRewardsFactory.
    - Can register pools for rewards creation.

#### [Voter](https://etherscan.io/address/0x0000000000000000000000000000000000000000#code)
- `VOTER_GOVERNOR_ROLE` (roleId `7`)
    - Can set the maximum number of pools that one can vote on.
    - Can set DAO fee for existing voting rewards and default DAO fee for futures ones.
    - Can restrict a user from voting.
    - Can whitelist tokens to be used as bribe reward tokens in voting rewards.
    - Can whitelist a user to vote during the privileged epoch window.
- `VOTER_EMERGENCY_COUNCIL_ROLE` (roleId `8`)
    - Can ban or reauthorize voting for a pool.

#### [FeesVotingReward](https://etherscan.io/address/0x0000000000000000000000000000000000000000#code)
- `FEES_VOTING_REWARDS_DISTRIBUTOR_ROLE` (roleId `10`)
    - Can create fees rewards (with any ERC20 and ETH).

#### [VotingEscrow](https://etherscan.io/address/0x0000000000000000000000000000000000000000#code)
- Admin
    - Can set admin in VotingEscrow.


## Contract Roles and Abilities
In addition to defined admin roles, `Voter` contract is granted the `VOTER_ROLE` (roleId `9`) which gives unique permissions in calling other contracts.

- Can deploy voting rewards contracts.
    - `Voter.createVotingRewards()`
- Can claim fees and rewards earned by veAPW holders that voted for corresponding pools.
    - `Voter.claimFees()`
    - `Voter.claimBribes()`
    - `Voter.claimBribesAndFees()`
- Can set voting status of a veAPW holder.
    - `Voter.vote()`
    - `Voter.reset()`
- Can deposit and withdraw balances from `BribeVotingReward` and `FeesVotingReward`.
    - `Voter.vote()`
    - `Voter.reset()`
- Can set DAO fee for `BribeVotingReward` and `FeesVotingReward`.
    - `Voter.setPoolsVotingRewardsDaoFee()`
    - `Voter.setVotingRewardsDaoFee()`
