// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {StewardRegistry} from "../src/StewardRegistry.sol";
import {Origen} from "../src/Origen.sol";
import {GaiaUsd} from "../src/GaiaUsd.sol";
import {TimeTokens} from "../src/TimeTokens.sol";
import {TrokenAyni} from "../src/TrokenAyni.sol";
import {AccountingTokens} from "../src/AccountingTokens.sol";
import {DonationCertNft} from "../src/DonationCertNft.sol";
import {SpiralsNft} from "../src/SpiralsNft.sol";
import {GaiaTreasury} from "../src/GaiaTreasury.sol";
import {TramoVestingFactory} from "../src/TramoVestingFactory.sol";
import {GaiaScoreResolver} from "../src/GaiaScoreResolver.sol";
import {GeoNFT} from "../src/vendor/geonft/GeoNFT.sol";
import {SDRegistry} from "../src/vendor/geonft/SDRegistry.sol";
import {IEAS} from "eas-contracts/IEAS.sol";

/// @title Deploy — Phase 0/1 Gaia CoRe deployment
/// @notice Deploys the full contract layer wired to a Safe multisig and the
///         canonical EAS deployment. GAIAUSD deploys too but is not activated
///         until Phase 4 (licensed e-money partner required).
///
/// Env vars:
///   SAFE_ADDRESS       — deployed Safe (3-of-N steward multisig), required
///   COMMON_FUND        — Common Fund address, defaults to SAFE
///   REINVESTMENT_SINK  — 90% reinvestment recipient, defaults to SAFE
///   EAS_ADDRESS        — EAS contract; defaults to canonical OP-stack predeploy
///   STEWARD_N          — initial steward addresses (STEWARD_1..STEWARD_K)
contract Deploy is Script {
    /// @notice Canonical EAS predeploy on OP-stack chains incl. Base.
    address constant EAS_CANONICAL = 0x4200000000000000000000000000000000000021;

    function run() external {
        address safe = vm.envAddress("SAFE_ADDRESS");
        address commonFund = vm.envOr("COMMON_FUND", safe);
        address reinvest = vm.envOr("REINVESTMENT_SINK", safe);
        IEAS eas = IEAS(vm.envOr("EAS_ADDRESS", EAS_CANONICAL));

        vm.startBroadcast();

        StewardRegistry registry = new StewardRegistry(safe);

        // Onboard initial stewards (must be called from the Safe itself via
        // its execTransaction; here we emit them as calldata suggestions).
        uint256 i = 1;
        while (true) {
            try vm.envAddress(string.concat("STEWARD_", vm.toString(i))) returns (address s) {
                console2.log("steward[%s] %s (register via Safe: addSteward)", i, s);
                i++;
            } catch {
                break;
            }
        }

        GaiaTreasury treasury = new GaiaTreasury(registry, commonFund, reinvest);
        Origen ori = new Origen(registry);
        GaiaUsd gusd = new GaiaUsd(registry, address(treasury));
        TimeTokens timeTokens = new TimeTokens(registry, "ipfs://gaia-time/{id}");
        TrokenAyni troken = new TrokenAyni(registry);
        AccountingTokens acct = new AccountingTokens(registry, "ipfs://gaia-acct/{id}");
        DonationCertNft cert = new DonationCertNft(registry);
        SpiralsNft spirals = new SpiralsNft(registry);
        TramoVestingFactory factory = new TramoVestingFactory(registry);
        GaiaScoreResolver resolver = new GaiaScoreResolver(eas, registry);
        GeoNFT geo = new GeoNFT(safe);
        SDRegistry sd = new SDRegistry(geo, safe);

        vm.stopBroadcast();

        console2.log("=== Gaia CoRe deployment ===");
        console2.log("StewardRegistry   ", address(registry));
        console2.log("GaiaTreasury      ", address(treasury));
        console2.log("Origen            ", address(ori));
        console2.log("GaiaUsd (Phase 4) ", address(gusd));
        console2.log("TimeTokens        ", address(timeTokens));
        console2.log("TrokenAyni        ", address(troken));
        console2.log("AccountingTokens  ", address(acct));
        console2.log("DonationCertNft   ", address(cert));
        console2.log("SpiralsNft        ", address(spirals));
        console2.log("TramoVestingFactory", address(factory));
        console2.log("GaiaScoreResolver ", address(resolver));
        console2.log("GeoNFT (TERRA)    ", address(geo));
        console2.log("SDRegistry        ", address(sd));
        console2.log("Safe multisig     ", safe);
        console2.log("EAS               ", address(eas));
    }
}
