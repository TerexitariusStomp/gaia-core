// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {StewardRegistry} from "../src/StewardRegistry.sol";
import {Origen} from "../src/Origen.sol";
import {GaiaUsd} from "../src/GaiaUsd.sol";
import {TimeTokens} from "../src/TimeTokens.sol";
import {TrokenAyni} from "../src/TrokenAyni.sol";
import {AccountingTokens} from "../src/AccountingTokens.sol";
import {DonationCertNft} from "../src/DonationCertNft.sol";
import {SpiralsNft} from "../src/SpiralsNft.sol";
import {GaiaTreasury} from "../src/GaiaTreasury.sol";
import {GeoNFT} from "../src/vendor/geonft/GeoNFT.sol";
import {SDRegistry} from "../src/vendor/geonft/SDRegistry.sol";
import {TramoVestingFactory, TramoVesting} from "../src/TramoVestingFactory.sol";
import {GaiaScoreResolver} from "../src/GaiaScoreResolver.sol";
import {IEAS, Attestation} from "eas-contracts/IEAS.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MCK") {}
    function mint(address to, uint256 a) external { _mint(to, a); }
}

/// @dev Minimal stand-in for the canonical EAS deployment — only what the
///      resolver's `onlyEAS` path needs (msg.sender check happens inside).
contract MockEAS {
    function callAttest(GaiaScoreResolver resolver, Attestation calldata a) external returns (bool) {
        return resolver.attest(a);
    }
}

contract GaiaCoreTest is Test {
    StewardRegistry registry;
    Origen ori;
    GaiaUsd gusd;
    TimeTokens timeTokens;
    TrokenAyni troken;
    AccountingTokens acct;
    DonationCertNft cert;
    SpiralsNft spirals;
    GaiaTreasury treasury;
    GeoNFT geo;
    SDRegistry sd;
    TramoVestingFactory factory;
    MockEAS eas;
    GaiaScoreResolver resolver;

    address multisig = address(0xA11CE);
    address s1 = address(0x51);
    address s2 = address(0x52);
    address s3 = address(0x53);
    address s4 = address(0x54);
    address alice = address(0xA1);
    address bob = address(0xB0B);
    address commonFund = address(0xC0FFEE);
    address reinvest = address(0xBEEF);

    function setUp() public {
        registry = new StewardRegistry(multisig);
        treasury = new GaiaTreasury(registry, commonFund, reinvest);
        ori = new Origen(registry);
        gusd = new GaiaUsd(registry, address(treasury));
        timeTokens = new TimeTokens(registry, "ipfs://gaia");
        troken = new TrokenAyni(registry);
        acct = new AccountingTokens(registry, "ipfs://gaia-acct");
        cert = new DonationCertNft(registry);
        spirals = new SpiralsNft(registry);

        vm.startPrank(multisig);
        registry.addSteward(s1);
        registry.addSteward(s2);
        registry.addSteward(s3);
        registry.addSteward(s4);
        vm.stopPrank();

        geo = new GeoNFT(multisig);
        sd = new SDRegistry(geo, multisig);
        factory = new TramoVestingFactory(registry);
        eas = new MockEAS();
        resolver = new GaiaScoreResolver(IEAS(address(eas)), registry);
    }

    function _quorum(bytes32 op) internal {
        vm.prank(s1); registry.approve(op);
        vm.prank(s2); registry.approve(op);
        vm.prank(s3); registry.approve(op);
    }

    // ---- StewardRegistry ------------------------------------------------

    function test_StewardMgmt() public {
        assertEq(registry.stewardCount(), 4);
        vm.prank(multisig);
        registry.revokeSteward(s4);
        assertEq(registry.stewardCount(), 3);
        assertFalse(registry.isSteward(s4));
    }

    function test_QuorumRequiresThree() public {
        bytes32 op = keccak256("op");
        vm.prank(s1); registry.approve(op);
        vm.prank(s2); registry.approve(op);
        assertFalse(registry.isApproved(op));
        vm.prank(s3); registry.approve(op);
        assertTrue(registry.isApproved(op));
    }

    function test_NonStewardCannotApprove() public {
        vm.expectRevert(StewardRegistry.NotSteward.selector);
        vm.prank(alice);
        registry.approve(keccak256("op"));
    }

    function test_ConsumeResetsApprovals() public {
        bytes32 op = keccak256("op2");
        _quorum(op);
        registry.consume(op);
        assertEq(registry.approvals(op), 0);
        assertFalse(registry.isApproved(op));
    }

    // ---- Origen ----------------------------------------------------------

    function test_OrigenMintNeedsQuorum() public {
        bytes32 assetRef = keccak256("asset1");
        vm.expectRevert();
        vm.prank(alice);
        ori.mintBacked(alice, 100 ether, assetRef);

        bytes32 op = keccak256(abi.encode("ORI_MINT", alice, 100 ether, assetRef));
        _quorum(op);
        ori.mintBacked(alice, 100 ether, assetRef);
        assertEq(ori.balanceOf(alice), 100 ether);
        assertEq(ori.totalSupply(), 100 ether);
    }

    function test_OrigenRedeem() public {
        bytes32 assetRef = keccak256("asset2");
        _quorum(keccak256(abi.encode("ORI_MINT", alice, 50 ether, assetRef)));
        ori.mintBacked(alice, 50 ether, assetRef);
        vm.prank(alice);
        ori.redeem(20 ether, keccak256("goods"));
        assertEq(ori.balanceOf(alice), 30 ether);
    }

    // ---- GaiaUsd ----------------------------------------------------------

    function test_GaiaUsdDemurrage() public {
        bytes32 reserveRef = keccak256("res");
        _quorum(keccak256(abi.encode("GAIAUSD_MINT", alice, 10_000 ether, reserveRef)));
        gusd.mintBacked(alice, 10_000 ether, reserveRef);
        assertEq(gusd.balanceOf(alice), 10_000 ether);

        vm.warp(block.timestamp + 30 days);
        assertEq(gusd.balanceOf(alice), 9_900 ether); // 1% decayed view

        gusd.settle(alice);
        assertEq(gusd.balanceOf(alice), 9_900 ether);
        assertEq(gusd.balanceOf(address(treasury)), 100 ether); // oxidized -> treasury
    }

    function test_GaiaUsdCompounds() public {
        bytes32 reserveRef = keccak256("res2");
        _quorum(keccak256(abi.encode("GAIAUSD_MINT", alice, 10_000 ether, reserveRef)));
        gusd.mintBacked(alice, 10_000 ether, reserveRef);

        vm.warp(block.timestamp + 90 days);
        gusd.settle(alice);
        // 10_000 * 0.99^3 = 9_702.99 (truncated each month)
        assertEq(gusd.balanceOf(alice), 9_702 ether + 99 ether / 100);
        assertApproxEqAbs(gusd.balanceOf(alice), 9_702.99 ether, 0.01 ether);
    }

    function test_GaiaUsdTransferSettles() public {
        bytes32 reserveRef = keccak256("res3");
        _quorum(keccak256(abi.encode("GAIAUSD_MINT", alice, 1_000 ether, reserveRef)));
        gusd.mintBacked(alice, 1_000 ether, reserveRef);
        vm.warp(block.timestamp + 30 days);

        vm.prank(alice);
        gusd.transfer(bob, 500 ether);
        // alice decayed 1% before sending: 990 raw -> 490 remains
        assertEq(gusd.balanceOf(alice), 490 ether);
        assertEq(gusd.balanceOf(bob), 500 ether);
        assertEq(gusd.balanceOf(address(treasury)), 10 ether);
    }

    // ---- TimeTokens -------------------------------------------------------

    function test_TimeTokensMint() public {
        bytes32 evidence = keccak256("e4-evidence");
        bytes32 op = keccak256(abi.encode("HOURS_MINT", alice, timeTokens.HREGEN(), 5, evidence));
        _quorum(op);
        timeTokens.mintVerifiedHours(alice, timeTokens.HREGEN(), 5, evidence);
        assertEq(timeTokens.balanceOf(alice, timeTokens.HREGEN()), 5 ether);
        assertEq(timeTokens.weeklyHours(block.timestamp / 7 days, alice), 5);
    }

    function test_TimeTokensWeeklyCap() public {
        bytes32 evidence = keccak256("ev");
        uint256 id = timeTokens.KHRONOS();
        bytes32 op = keccak256(abi.encode("HOURS_MINT", bob, id, 48, evidence));
        _quorum(op);
        timeTokens.mintVerifiedHours(bob, id, 48, evidence);

        bytes32 op2 = keccak256(abi.encode("HOURS_MINT", bob, id, 1, evidence));
        _quorum(op2);
        vm.expectRevert();
        timeTokens.mintVerifiedHours(bob, id, 1, evidence);
    }

    function test_TimeTokensCapResetsWeekly() public {
        bytes32 evidence = keccak256("ev2");
        uint256 id = timeTokens.HSOCIAL();
        bytes32 op = keccak256(abi.encode("HOURS_MINT", bob, id, 48, evidence));
        _quorum(op);
        timeTokens.mintVerifiedHours(bob, id, 48, evidence);

        vm.warp(block.timestamp + 7 days);
        bytes32 op2 = keccak256(abi.encode("HOURS_MINT", bob, id, 10, evidence));
        _quorum(op2);
        timeTokens.mintVerifiedHours(bob, id, 10, evidence);
        assertEq(timeTokens.balanceOf(bob, id), 58 ether);
    }

    // ---- TrokenAyni ---------------------------------------------------------

    function test_TrokenOnboardingCredit() public {
        vm.prank(alice);
        troken.openAccount();
        assertEq(troken.creditLine(alice), 33 ether);
        assertEq(troken.spendableOf(alice), 33 ether);

        // Spend up to the credit line (goes negative)
        vm.prank(alice);
        troken.transfer(bob, 33 ether);
        assertEq(troken.creditBalanceOf(alice), -33 ether);
        assertEq(troken.creditBalanceOf(bob), 33 ether);

        // Over the limit reverts
        vm.expectRevert();
        vm.prank(alice);
        troken.transfer(bob, 1 wei);
    }

    function test_TrokenCreditLineCap() public {
        bytes32 op = keccak256(abi.encode("TROKEN_CREDIT", alice, 200_000 ether));
        _quorum(op);
        vm.expectRevert(
            abi.encodeWithSelector(
                TrokenAyni.CapExceeded.selector, 200_000 ether, troken.MAX_CREDIT_LINE()
            )
        );
        troken.setCreditLine(alice, 200_000 ether);

        bytes32 op2 = keccak256(abi.encode("TROKEN_CREDIT", alice, 333 ether));
        _quorum(op2);
        troken.setCreditLine(alice, 333 ether);
        assertEq(troken.creditLine(alice), 333 ether);
    }

    function test_TokenClearingCycle() public {
        vm.prank(alice);
        troken.openAccount();
        vm.prank(alice);
        troken.transfer(bob, 10 ether);
        assertEq(troken.creditBalanceOf(alice), -10 ether);

        vm.expectRevert(); // too early
        troken.clearCycle(alice);

        vm.warp(block.timestamp + 366 days);
        troken.clearCycle(alice);
        assertEq(troken.defaultedTotal(), 10 ether);
    }

    // ---- AccountingTokens --------------------------------------------------

    function test_AccountingSoulbound() public {
        bytes32 ref = keccak256("don1");
        _quorum(keccak256(abi.encode("ACCT_MINT", acct.DONATION(), alice, 500, ref)));
        uint256 id = acct.DONATION();
        acct.mintDonationReceipt(alice, 500, ref);
        assertEq(acct.balanceOf(alice, id), 500);

        vm.expectRevert(AccountingTokens.NonTransferable.selector);
        vm.prank(alice);
        acct.safeTransferFrom(alice, bob, id, 100, "");
    }

    function test_CommonsIndicator() public {
        bytes32 ref = keccak256("land");
        _quorum(keccak256(abi.encode("ACCT_MINT", acct.COMMONS(), multisig, 1_000_000, ref)));
        acct.mintCommonsIndicator(1_000_000, ref);
        assertEq(acct.balanceOf(multisig, acct.COMMONS()), 1_000_000);
    }

    // ---- DonationCertNft ----------------------------------------------------

    function test_DonationCertSoulbound() public {
        bytes32 purpose = keccak256("biohub-medellin");
        _quorum(keccak256(abi.encode("DONATION_CERT", alice, 5_000 ether, "ESAL Fundacion Gaia", purpose)));
        uint256 id = cert.issue(alice, 5_000 ether, "ESAL Fundacion Gaia", purpose);
        assertEq(cert.ownerOf(id), alice);

        (uint256 amount,, string memory custodian,) = cert.certificates(id);
        assertEq(amount, 5_000 ether);
        assertEq(custodian, "ESAL Fundacion Gaia");

        vm.expectRevert(DonationCertNft.NonTransferable.selector);
        vm.prank(alice);
        cert.transferFrom(alice, bob, id);
    }

    // ---- SpiralsNft ----------------------------------------------------------

    function test_SpiralsDiploma() public {
        bytes32 project = keccak256("terra-cundinamarca");
        _quorum(keccak256(abi.encode("SPIRALS_ISSUE", alice, project, 2_000 ether)));
        uint256 id = spirals.issue(alice, project, 2_000 ether);
        assertEq(spirals.ownerOf(id), alice);
        assertEq(spirals.recognizedAmount(id), 2_000 ether);

        vm.expectRevert(SpiralsNft.NonTransferable.selector);
        vm.prank(alice);
        spirals.transferFrom(alice, bob, id);
    }

    function test_SpiralsReciprocityIsRecordedNotPromised() public {
        bytes32 project = keccak256("p1");
        _quorum(keccak256(abi.encode("SPIRALS_ISSUE", alice, project, 1_000 ether)));
        uint256 id = spirals.issue(alice, project, 1_000 ether);

        bytes32 note = keccak256("gratitude");
        bytes32 op = keccak256(abi.encode("SPIRALS_GRANT", id, address(ori), 50 ether, note));
        _quorum(op);
        vm.expectEmit(true, true, true, true);
        emit SpiralsNft.ReciprocityGranted(id, address(ori), 50 ether, note);
        spirals.recordReciprocity(id, address(ori), 50 ether, note);
    }

    // ---- GaiaTreasury ---------------------------------------------------------

    function test_TreasurySplits90_10() public {
        MockToken t = new MockToken();
        t.mint(address(treasury), 1_000 ether);

        bytes32 op = keccak256(abi.encode("SURPLUS", address(t), 1_000 ether));
        _quorum(op);
        treasury.distributeSurplus(t, 1_000 ether);

        assertEq(t.balanceOf(commonFund), 100 ether);   // 10%
        assertEq(t.balanceOf(reinvest), 900 ether);     // 90%
    }

    // ---- GeoNFT + SDRegistry (TERRA / GAIABIO) ------------------------------

    function test_GeoNFTMintAndSpatialQuery() public {
        string memory geojson = '{"type":"Polygon","coordinates":[[]]}';
        geo.safeMint(alice, "ipfs://terra1", geojson);
        assertEq(geo.ownerOf(0), alice);
        assertEq(geo.geoJson(0), geojson);

        // Medellín ~6.2442°N, -75.5812°W at 1e6 precision
        vm.prank(multisig);
        sd.registerGeoNFT(0, [int64(6_244_200), int64(-75_581_200)]);
        assertTrue(sd.isRegistered(0));
        assertEq(sd.getAllGeoNFTs().length, 1);

        uint256[] memory hits = sd.queryGeoNFTsByLatLng(6_244_200, -75_581_200, 8);
        assertEq(hits.length, 1);
        assertEq(hits[0], 0);
    }

    function test_SDRegistryUnregister() public {
        geo.safeMint(alice, "ipfs://t", "{}");
        vm.prank(multisig);
        sd.registerGeoNFT(0, [int64(6_000_000), int64(-75_000_000)]);
        vm.prank(multisig);
        sd.unregisterGeoNFT(0);
        assertFalse(sd.isRegistered(0));
        assertEq(sd.getAllGeoNFTs().length, 0);
    }

    function test_OnlyStewardMultisigRegisters() public {
        geo.safeMint(alice, "ipfs://t", "{}");
        vm.expectRevert();
        vm.prank(alice);
        sd.registerGeoNFT(0, [int64(0), int64(0)]);
    }

    // ---- TramoVestingFactory (pledge tramos) --------------------------------

    function test_TramoVesting() public {
        uint64 start = uint64(block.timestamp);
        uint64 duration = 365 days;
        uint64 cliff = 90 days;

        vm.expectRevert();
        factory.createTramo(bob, start, duration, cliff);

        bytes32 op = keccak256(abi.encode("TRAMO", bob, start, duration, cliff));
        _quorum(op);
        TramoVesting vesting = factory.createTramo(bob, start, duration, cliff);

        MockToken t = new MockToken();
        t.mint(address(vesting), 1_000 ether);

        assertEq(vesting.releasable(address(t)), 0); // before cliff
        vm.warp(start + 180 days);                   // past cliff, ~half-vested
        uint256 rel = vesting.releasable(address(t));
        assertGt(rel, 400 ether);
        assertLt(rel, 600 ether);

        vm.prank(bob);
        vesting.release(address(t));
        assertEq(t.balanceOf(bob), rel);
    }

    // ---- GaiaScoreResolver (EAS reputation) ----------------------------------

    function _attestation(address attester) internal view returns (Attestation memory) {
        return Attestation({
            uid: bytes32(uint256(1)),
            schema: bytes32(uint256(2)),
            time: uint64(block.timestamp),
            expirationTime: 0,
            revocationTime: 0,
            refUID: bytes32(0),
            recipient: alice,
            attester: attester,
            revocable: true,
            data: ""
        });
    }

    function test_ResolverOnlyStewardsAttest() public {
        Attestation memory a = _attestation(s1);
        assertTrue(eas.callAttest(resolver, a));

        Attestation memory bad = _attestation(alice);
        vm.expectRevert();
        eas.callAttest(resolver, bad);
    }
}
