## Deploy Spectra Governance

Spectra Governance deployment is a multi-step process. Unlike testing, we cannot impersonate governance to submit transactions and must wait on the necessary protocol actions to complete setup. This README goes through the necessary instructions to deploy the Spectra Governance contracts.

### Environment setup
1. Copy-pasta `.env.sample` into a new `.env` and set the environment variables. `PRIVATE_KEY_DEPLOY` is the private key to deploy all scripts.
2. Copy-pasta `script/constants/TEMPLATE.json` into a new file `script/constants/{CONSTANTS_FILENAME}`. For example, "Mainnet.json" in the .env would be a file of `script/constants/Mainnet.json`.  Set the variables in the new file.

3. Run tests to ensure deployment state is configured correctly:
```ml
forge init
forge build
forge test
```

*Note that this will create a `script/constants/output/{OUTPUT_FILENAME}` file with the contract addresses created in testing.  If you are using the same constants for multiple deployments (for example, deploying in a local fork and then in prod), you can rename `OUTPUT_FILENAME` to store the new contract addresses while using the same constants.

4. Ensure all v2 deployments are set properly. In project directory terminal:
```
source .env
```

### Deployment
- If deploying to a chain other than Ethereum Mainnet / Sepolia, `foundry.toml` should be updated with relevant .env variable names corresponding to `RPC_URL`, `SCAN_API_KEY` and `ETHERSCAN_VERIFIER_URL`.

1. Deploy Spectra Governance
```
forge script script/DeploySpectraGovernance.s.sol:DeploySpectraGovernance --broadcast --slow --rpc-url mainnet --verify -vvvv
```

2. Deploy voting rewards. These voting rewards are created around existing pools.
```
forge script script/DeployVotingRewards.s.sol:DeployVotingRewards --broadcast --slow --rpc-url mainnet --verify -vvvv
```