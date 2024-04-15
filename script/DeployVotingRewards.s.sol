// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "forge-std/StdJson.sol";
import "../test/Base.sol";

/// @notice Deploy script to deploy new pools and voting rewards
contract DeployVotingRewards is Script {
    using stdJson for string;

    uint256 public deployPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOY");
    address public deployerAddress = vm.addr(deployPrivateKey);
    string public constantsFilename = vm.envString("CONSTANTS_FILENAME");
    string public outputFilename = vm.envString("OUTPUT_FILENAME");
    string public jsonConstants;
    string public jsonOutput;

    Voter public voter;
    GovernanceRegistry public governanceRegistry;

    constructor() {}

    function run() public {
        string memory root = vm.projectRoot();
        string memory basePath = string.concat(root, "/script/constants/");
        string memory path = string.concat(basePath, constantsFilename);

        // load in vars
        jsonConstants = vm.readFile(path);
        Base.PoolToRegister[] memory _pools = abi.decode(
            vm.parseJson(jsonConstants, ".pools"),
            (Base.PoolToRegister[])
        );

        // Read output from DeploySpectraGovernance script
        path = string.concat(basePath, "output/DeploySpectraGovernance-");
        path = string.concat(path, outputFilename);
        jsonOutput = vm.readFile(path);
        voter = Voter(abi.decode(vm.parseJson(jsonOutput, ".Voter"), (address)));
        governanceRegistry = GovernanceRegistry(abi.decode(vm.parseJson(jsonOutput, ".GovernanceRegistry"), (address)));

        vm.startBroadcast(deployerAddress);
        string memory obj1 = "pool key";
        string memory list;
        // Deploy all voting rewards
        for (uint256 i = 0; i < _pools.length; i++) {
            uint160 _poolId = governanceRegistry.getPoolId(_pools[i].addr, _pools[i].chainId);
            (address feesVotingReward, address bribeVotingReward) = voter.createVotingRewards(_poolId);
            // Write to file
            string memory obj2 = "pool data";
            vm.serializeAddress(obj2, "pool", _pools[i].addr);
            vm.serializeUint(obj2, "chainId", _pools[i].chainId);
            vm.serializeAddress(obj2, "feesVotingRewards", feesVotingReward);
            string memory poolOutput = vm.serializeAddress(obj2, "bribeVotingRewards", bribeVotingReward);
            list = vm.serializeString(obj1, vm.toString(_poolId), poolOutput);
        }
        vm.stopBroadcast();

        // Write to file
        path = string.concat(basePath, "output/DeployVotingRewards-");
        path = string.concat(path, outputFilename);

        string memory key = "key-deploy-voting-rewards-output-file";
        vm.writeJson(vm.serializeString(key, "poolsVotingRewards", list), path);
    }
}
