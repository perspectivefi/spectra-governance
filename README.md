# Spectra Tokenomics

Contracts for Spectra Finance tokenomics. Voting and fee distribution mechanisms were forked from Velodrome Finance and edited to fit Spectra’s use case.

See `SPECIFICATION.md` for more detail.

## Protocol Overview

### Tokenomy contracts

| Filename | Description |
| --- | --- |
| `VotingEscrow.vy` | ERC20 token representing the protocol vote-escrow lock (veAPW). Written in Vyper and already deployed on [Mainnet](https://etherscan.io/address/0xC5ca1EBF6e912E49A6a70Bb0385Ea065061a4F09). |
| `FeeDistributor.vy` | Reward contract for distribution of APW locking rewards. Written in Vyper and already deployed on [Mainnet](https://etherscan.io/address/0x4104b135DBC9609Fc1A9490E61369036497660c8). |

### Governance mechanics contracts

| Filename | Description |
| --- | --- |
| `GovernanceRegistry.sol` | Stores Spectra Core Registry, VotingRewardsFactory and registered pools addresses. |
| `Voter.sol` | Handles votes for the current epoch and voting rewards creation. |
| `VotingRewardFactory.sol` | Factory for creation of voting rewards. |
| `VotingReward.sol` | Rewards contracts used by `FeesVotingReward.sol` and `BribeVotingReward.sol`. Rewards are distributed in the following epoch proportionally based on the last checkpoint created by the user, and are earned through "voting" for a pool. |
| `FeesVotingReward.sol` | Stores LP fees (from associated pool) to be distributed for the current voting epoch to pool's voters. |
| `BribeVotingReward.sol` | Stores the users/externally provided rewards for the current voting epoch to associated pool's voters. These are deposited externally every week. |

![](assets/spectra-gov-architecture.svg)

## Installation

Follow [this link](https://book.getfoundry.sh/getting-started/installation) to install foundry, forge, cast and anvil

Do not forget to update foundry regularly with the following command

```properties
foundryup
```

Similarly for forge-std run

```properties
forge update lib/forge-std
```

## Submodules

Run below command to include/update all git submodules like openzeppelin contracts, forge-std etc (`lib/`)

```properties
git submodule update --init --recursive
```

To get the `node_modules/` directory run

```properties
yarn
```

## Compilation

To compile your contracts run

```properties
forge build
```

## Testing

Run your tests with

```properties
forge test
```

## Testing

### Ethereum Mainnet Fork Tests

- In order to run mainnet fork tests against ethereum, inherit `BaseTest` in `BaseTest.sol` in your new class and set the `deploymentType` variable to `Deployment.FORK`.
- The `MAINNET_RPC_URL` field must be set in `.env`.
- Additionally, `FORK_BLOCK_NUMBER` should be set to `18244804` in the `.env` file as tests are using an already deployed veAPW contract, and some expected values in tests have been adjusted to match this starting block.

Run your tests with

```properties
forge test -vv
```

Find more information on testing with foundry [here](https://book.getfoundry.sh/forge/tests)

## Lint

`yarn format` to run prettier.

`yarn lint` to run solhint (currently disabled in CI).

## Deployment

See `script/README.md` for more detail.

## Security

For general information about security include audits, bug bounty and deployed contracts, go [here](https://docs.spectra.finance/security).

### Access Control
See `PERMISSIONS.md` for more detail.

## Mainnet Deployment

| Name               | Address                                                                                                                               |
| :----------------- | :------------------------------------------------------------------------------------------------------------------------------------ |
| VotingEscrow           | [0xC5ca1EBF6e912E49A6a70Bb0385Ea065061a4F09](https://etherscan.io/address/0xC5ca1EBF6e912E49A6a70Bb0385Ea065061a4F09#code) |
| AccessManager          | [0x7EA3097E2AF59eA705398544e0f58EdDb7bd1852](https://etherscan.io/address/0x7EA3097E2AF59eA705398544e0f58EdDb7bd1852#code) |
| SpectraForwarder       | [0xD187CB71fe8201935e6676ff872239Fff552D4a5](https://etherscan.io/address/0xD187CB71fe8201935e6676ff872239Fff552D4a5#code) |
| GovernanceRegistry     | [0x4425779F145f6599CFCeAa9443b497a7a2DFdB17](https://etherscan.io/address/0x4425779F145f6599CFCeAa9443b497a7a2DFdB17#code) |
| Voter                  | [0x3d72440af4b0312084BC51A2038180876D208832](https://etherscan.io/address/0x3d72440af4b0312084BC51A2038180876D208832#code) |
| VotingRewardsFactory   | [0x9D9CF84e7e9411b593549118d15092064c8ed888](https://etherscan.io/address/0x9D9CF84e7e9411b593549118d15092064c8ed888#code) |
