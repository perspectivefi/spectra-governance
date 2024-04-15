// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "../script/DeploySpectraGovernance.s.sol";
import "../script/DeployVotingRewards.s.sol";

import "./BaseTest.sol";

contract TestDeploy is BaseTest {
    using stdJson for string;
    using stdStorage for StdStorage;

    string public constantsFilename = vm.envString("CONSTANTS_FILENAME");
    string public jsonConstants;

    address public constant testDeployer = 0xDbbfc051D200438dd5847b093B22484B842de9E7; // DAO address on Eth Mainnet

    // Scripts to test
    DeploySpectraGovernance deploySpectraGovernance;
    DeployVotingRewards deployVotingRewards;

    constructor() {
        deploymentType = Deployment.CUSTOM;
    }

    function _setUp() public override {
        deploySpectraGovernance = new DeploySpectraGovernance();
        deployVotingRewards = new DeployVotingRewards();

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/script/constants/");
        path = string.concat(path, constantsFilename);

        jsonConstants = vm.readFile(path);

        dao = abi.decode(vm.parseJson(jsonConstants, ".DAO"), (address));
        emergencyCouncil = abi.decode(vm.parseJson(jsonConstants, ".emergencyCouncil"), (address));

        accessManager = AccessManager(abi.decode(vm.parseJson(jsonConstants, ".accessManager"), (address)));

        // Use test account for deployment
        stdstore.target(address(deploySpectraGovernance)).sig("deployerAddress()").checked_write(testDeployer);
        stdstore.target(address(deployVotingRewards)).sig("deployerAddress()").checked_write(testDeployer);
        vm.deal(testDeployer, TOKEN_10K);
    }

    function testLoadedState() public {
        // If tests fail at this point- you need to set the .env and the constants used for deployment.
        // Refer to script/README.md
        assertTrue(dao != address(0));
        assertTrue(emergencyCouncil != address(0));
    }

    function testDeployScript() public {
        deploySpectraGovernance.run();
        deployVotingRewards.run();

        // DeploySpectraGovernance checks

        // ensure all tokens are added to voter
        address[] memory _tokens = abi.decode(vm.parseJson(jsonConstants, ".whitelistBribeTokens"), (address[]));
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            assertTrue(deploySpectraGovernance.voter().isWhitelistedBribeToken(token));
        }
        assertTrue(deploySpectraGovernance.voter().isWhitelistedBribeToken(address(deploySpectraGovernance.APW())));

        // v2 core
        // From _coreSetup()
        assertTrue(address(deploySpectraGovernance.forwarder()) != address(0));

        // Permissions
        assertEq(deploySpectraGovernance.governanceRegistry().authority(), address(accessManager));
        assertEq(deploySpectraGovernance.voter().authority(), address(accessManager));

        // DeployVotingRewards checks

        // Validate pools and voting rewards
        PoolToRegister[] memory _pools = abi.decode(jsonConstants.parseRaw(".pools"), (PoolToRegister[]));
        for (uint256 i = 0; i < _pools.length; i++) {
            uint160 _poolId = deploySpectraGovernance.governanceRegistry().getPoolId(_pools[i].addr, _pools[i].chainId);
            assertTrue(_poolId != 0);
            address feesVotingReward = deploySpectraGovernance.voter().poolToFees(_poolId);
            address bribeVotingReward = deploySpectraGovernance.voter().poolToBribe(_poolId);
            assertTrue(feesVotingReward != address(0));
            assertTrue(bribeVotingReward != address(0));
        }
    }
}
