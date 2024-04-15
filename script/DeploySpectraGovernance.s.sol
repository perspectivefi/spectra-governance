// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "forge-std/StdJson.sol";
import "../test/Base.sol";

contract DeploySpectraGovernance is Base {
    using stdJson for string;
    string public basePath;
    string public path;

    uint256 public deployPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOY");
    address public deployerAddress = 0xDbbfc051D200438dd5847b093B22484B842de9E7;
    string public constantsFilename = vm.envString("CONSTANTS_FILENAME");
    string public outputFilename = vm.envString("OUTPUT_FILENAME");
    string public jsonConstants;
    string public jsonOutput;

    constructor() {
        string memory root = vm.projectRoot();
        basePath = string.concat(root, "/script/constants/");

        // load constants
        path = string.concat(basePath, constantsFilename);
        jsonConstants = vm.readFile(path);
    }

    function run() public {
        _deploySetupBefore();
        _coreSetup();
        _deploySetupAfter();
    }

    function _deploySetupBefore() public {
        // more constants loading - this needs to be done in-memory and not storage
        address[] memory _tokens = abi.decode(vm.parseJson(jsonConstants, ".whitelistBribeTokens"), (address[]));
        for (uint256 i = 0; i < _tokens.length; i++) {
            tokens.push(_tokens[i]);
        }

        PoolToRegister[] memory _poolsToRegister = abi.decode(
            vm.parseJson(jsonConstants, ".pools"),
            (PoolToRegister[])
        );
        for (uint256 i; i < _poolsToRegister.length; i++) {
            poolsToRegister.push(_poolsToRegister[i]);
        }

        // Loading output and use output path to later save deployed contracts
        basePath = string.concat(basePath, "output/");
        path = string.concat(basePath, "DeploySpectraGovernance-");
        path = string.concat(path, outputFilename);
        jsonOutput = vm.readFile(path);

        dao = abi.decode(vm.parseJson(jsonConstants, ".DAO"), (address));
        emergencyCouncil = abi.decode(vm.parseJson(jsonConstants, ".emergencyCouncil"), (address));
        feesVotingRewardsDistributor = abi.decode(
            vm.parseJson(jsonConstants, ".feesVotingRewardsDistributor"),
            (address)
        );

        APW = IERC20(abi.decode(vm.parseJson(jsonConstants, ".APW"), (address)));
        tokens.push(address(APW));

        escrow = IVotingEscrow(abi.decode(vm.parseJson(jsonConstants, ".veAPW"), (address)));

        accessManager = AccessManager(abi.decode(vm.parseJson(jsonConstants, ".accessManager"), (address)));

        // start broadcasting transactions
        vm.startBroadcast(deployerAddress);

        (bool hasRegistryRole, ) = accessManager.hasRole(Roles.REGISTRY_ROLE, deployerAddress);
        if (!hasRegistryRole) {
            accessManager.grantRole(Roles.REGISTRY_ROLE, deployerAddress, 0);
        }
        accessManager.grantRole(Roles.VOTER_GOVERNOR_ROLE, dao, 0);
        accessManager.grantRole(Roles.VOTER_EMERGENCY_COUNCIL_ROLE, emergencyCouncil, 0);
        // @TODO execute following line after rewarder deployment
        // accessManager.grantRole(Roles.FEES_VOTING_REWARDS_DISTRIBUTOR_ROLE, feesVotingRewardsDistributor, 0);
    }

    function _deploySetupAfter() public {
        // finish broadcasting transactions
        vm.stopBroadcast();

        string memory key = "key-deploy-governance-output-file";

        // write to file;
        vm.writeJson(vm.serializeAddress(key, "AccessManager", address(accessManager)), path);
        vm.writeJson(vm.serializeAddress(key, "Forwarder", address(forwarder)), path);
        vm.writeJson(vm.serializeAddress(key, "GovernanceRegistry", address(governanceRegistry)), path);
        vm.writeJson(vm.serializeAddress(key, "Voter", address(voter)), path);
        vm.writeJson(vm.serializeAddress(key, "VotingRewardsFactory", address(votingRewardsFactory)), path);
    }
}
