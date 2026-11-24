// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StewardRegistry} from "../src/StewardRegistry.sol";
import {GaiaScoreResolver} from "../src/GaiaScoreResolver.sol";
import {IEAS, AttestationRequest, AttestationRequestData} from "eas-contracts/IEAS.sol";
import {ISchemaRegistry, ISchemaResolver} from "eas-contracts/ISchemaRegistry.sol";

/// @notice Fork test against the canonical EAS deployment on Base mainnet.
///         Runs only when BASE_RPC_URL (or default public endpoint) is
///         reachable: `forge test --match-contract GaiaScoreFork -vvv`.
contract GaiaScoreForkTest is Test {
    address constant EAS = 0x4200000000000000000000000000000000000021;
    address constant SCHEMA_REGISTRY = 0x4200000000000000000000000000000000000020;

    address multisig = address(0xA11CE);
    address steward = address(0x51);
    address member = address(0xA1);

    StewardRegistry registry;
    GaiaScoreResolver resolver;
    bytes32 schemaUID;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org")));

        registry = new StewardRegistry(multisig);
        vm.prank(multisig);
        registry.addSteward(steward);

        resolver = new GaiaScoreResolver(IEAS(EAS), registry);

        schemaUID = ISchemaRegistry(SCHEMA_REGISTRY).register(
            "string region, uint8 certificationLevel, uint64 issuedAt, string evidenceURI",
            ISchemaResolver(address(resolver)),
            true
        );
    }

    function _request(address recipient) internal view returns (AttestationRequest memory) {
        return AttestationRequest({
            schema: bytes32(0), // patched by caller
            data: AttestationRequestData({
                recipient: recipient,
                expirationTime: 0,
                revocable: true,
                refUID: bytes32(0),
                data: abi.encode("medellin", uint8(3), uint64(block.timestamp), "ipfs://evidence"),
                value: 0
            })
        });
    }

    function testFork_StewardCanAttest() public {
        AttestationRequest memory req = _request(member);
        req.schema = schemaUID;

        vm.prank(steward);
        bytes32 uid = IEAS(EAS).attest(req);
        assertTrue(uid != bytes32(0));
    }

    function testFork_NonStewardAttestReverts() public {
        AttestationRequest memory req = _request(member);
        req.schema = schemaUID;

        vm.expectRevert();
        vm.prank(member);
        IEAS(EAS).attest(req);
    }
}
