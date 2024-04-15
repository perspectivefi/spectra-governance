# Spectra Finance Tokenomics Specification

Spectra tokenomics are based on Velodrome V2, based itself on the Solidly architecture.

## Definitions

- APW: The native ERC-20 compliant token in the Spectra ecosystem.
- Epoch: An epoch is one week in length, beginning at Thursday midnight UTC time.
- Pool: Curve pool.

## Token

### APW

Standard ERC20 token following OpenZeppelin's `ERC20PresetMinterPauserUpgradeable` preset.

### VotingEscrow

The APW token can be escrowed in the veAPW contract, which follows a non-standard ERC20 implementation.
A veAPW balance represents the voting weight of the escrowed tokens, and decays linearly over time.
APW tokens can be locked for a maximum of two years. veAPW vote weights can be used to vote for pools,
which in turn determines the proportion of weekly emissions that go to each pool LPs.

Standard Operations:
All of these operations require ownership of APW tokens. 
- Can create a veAPW lock by escrowing APW tokens and "locking" them for a time period.
- Can be transferred as supported by the ERC-20 interface.
- Can withdraw escrowed APW tokens once the user lock expires. 
- Can add to an existing user lock by escrowing additional APW tokens.
- Can increase the user lock duration (thus increasing voting power).

See `VOTINGESCROW.md` for a visual respresentation.

### FeeDistributor

Standard Curve-fee distribution contract. veAPW lock owners will earn rewards proportionally
based on their contribution to the total lockedAPW.

## Protocol

### Voter

The `Voter` contract is in charge of managing votes and voting rewards creation in the
Spectra ecosystem. Votes can be cast once per epoch, and earn veAPW owners both bribes
and fees from the pool they voted for. Voting can take place at any time during an epoch
except during the first and last hour of that epoch. In the last hour prior to epoch flip,
only whitelisted users can vote.

Once per epoch, LP depositors for registered pools will receive emissions from the Spectra
DAO proportionate to the amount of votes that the pools receive. Voter also contains several
utility functions that make claiming voting rewards easier. 

In the first hour of every epoch, the ability to `vote`, `poke` or `reset` is disabled to allow
distributions to take place. Voting is also disabled in the last hour of every epoch. However,
certain whitelisted users will be able to vote in this one hour window.

Standard Operations:
- Can vote once per epoch, with voting power proportional to veAPW balance at time of vote.
- Can reset vote weights any time after the epoch that you voted. Your ability to vote in the week that you reset is preserved.
- Can poke, i.e update user voting balances in voting rewards contracts.
- Can bulk claim voting rewards (i.e. bribes and/or fees).
- Can create voting reward contracts for a pool (must be a pool registered in `Registry`).

### VotingReward

The base voting reward contract for bribes and fees rewards. Voting rewards accrue to users that vote for a specific pool. Individual voting balance checkpoints and total supply checkpoints are created in a voting reward contract whenever a user votes for a pool. Checkpoints do not automatically update when voting power decays (requires `Voter.poke`). Rewards in these contracts are distributed proportionally to a user's voting power contribution to a pool. A user is distributed rewards in each epoch proportional to its voting power contribution in that epoch.

### FeesVotingReward

The fee voting reward derives from the fees relinquished by Spectra DAO. Fees are synchronized with bribes and accrue in the same way.
Thus, fees that accrue during epoch `n` will be distributed to voters of that pool in epoch `n+1`.

### BribeVotingReward

Bribe voting rewards are externally deposited rewards of whitelisted tokens (see `Voter`) used to incentivize users to vote for a given pool.

### Access Manager

Similarly than for the Spectra protocol, contracts in this repository implement the [OpenZeppelin AccessManager](https://docs.openzeppelin.com/contracts/5.x/api/access#accessmanager). See [PERMISSIONS.md](https://github.com/perspectivefi/tokenomics_update/blob/main/PERMISSIONS.md) for more details.

Roles use in tokenomics contracts are defined as follows:
- `ADMIN_ROLE` - roleId `0` - the Access Manager super admin. Can grant and revoke any role. Set by default in the Access Manager constructor.
- `REGISTRY_ROLE` - roleId `4` - the address that can call the registry contract to register new contracts addresses.
- `VOTER_GOVERNOR_ROLE` - roleId `7` - the address that acts as governor of the tokenomics contracts
- `VOTER_EMERGENCY_COUNCIL_ROLE` - roleId `8` - the address that acts as a credibly neutral party similar to Curve's Emergency DAO. This user can ban and reauthorise voting for specific pools. 
- `VOTER_ROLE` - roleId `9` - the `Voter` contract.
- `FEES_VOTING_REWARDS_DISTRIBUTOR_ROLE` - roleId `10` - the address that can create fees rewards.

### Util Libraries
- **Roles**: Provides identifiers for roles used in Spectra protocol.
- **SafeCastLibrary**: Safely converts unsigned and signed integers without overflow / underflow.
- **VelodromeTimeLibrary**: Computes start / end of epochs and voting windows.