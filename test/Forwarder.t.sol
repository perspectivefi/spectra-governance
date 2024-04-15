// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "./BaseTest.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./utils/ERC2771Helper.sol";

contract ForwarderTest is BaseTest {
    using ECDSA for bytes32;

    // first public/private key provided by anvil
    address sender = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 senderPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    ERC2771Helper erc2771Helper;

    function _setUp() public override {
        erc2771Helper = new ERC2771Helper();

        // fund forwarder with ETH for txs and fund from with APW
        vm.deal(address(forwarder), 1e18);
        deal(address(APW), sender, TOKEN_100K, true);

        // Approve owner and sender transfers of APW
        APW.approve(address(escrow), type(uint256).max);
        vm.prank(sender);
        APW.approve(address(escrow), type(uint256).max);
    }

    function testForwarderVote() public {
        assertTrue(!voter.voted(sender));

        skip(1 hours + 1);
        vm.prank(sender, sender);
        escrow.create_lock(TOKEN_1, block.timestamp + MAXTIME);
        uint160[] memory poolIds = new uint160[](1);
        poolIds[0] = poolId1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        // build request
        bytes memory payload = abi.encodeWithSelector(voter.vote.selector, sender, poolIds, weights);
        bytes32 requestType = erc2771Helper.registerRequestType(
            forwarder,
            "vote",
            "uint256 _user,uint160[] _poolVote,uint256[] _weights"
        );

        handleRequest(address(voter), payload, requestType);

        assertTrue(voter.voted(sender));
    }

    function handleRequest(address _to, bytes memory payload, bytes32 requestType) internal {
        IForwarder.ForwardRequest memory request = IForwarder.ForwardRequest({
            from: sender,
            to: _to,
            value: 0,
            gas: 5_000_000,
            nonce: forwarder.getNonce(sender),
            data: payload,
            validUntil: 0
        });

        bytes32 domainSeparator = erc2771Helper.registerDomain(
            forwarder,
            Strings.toHexString(uint256(uint160(_to)), 20),
            "1"
        );

        bytes memory suffixData = "0";
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(forwarder._getEncoded(request, requestType, suffixData))
            )
        );

        // sign request
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(senderPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        require(digest.recover(signature) == request.from, "FWD: signature mismatch");

        forwarder.execute(request, domainSeparator, requestType, suffixData, signature);
    }
}
