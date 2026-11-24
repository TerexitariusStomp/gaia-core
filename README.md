# Gaia Core — CoRe Monetary Layer

Solidity implementation of the Gaia Commons "Common Regenerative Economy" (CoRe)
token layer, per the audited master document and the November 2026 response spec.

All privileged issuance flows through `StewardRegistry` — a quorum of at least
3 certified Treasury Stewards must approve each operation hash before a managed
contract consumes it. There is no token-weighted voting anywhere in this layer.

## Contracts

| Contract | Dimension | Purpose |
|---|---|---|
| `StewardRegistry` | Governance | Certification-of-Trust steward set + 3-of-N operation approval/consume |
| `Origen` (ORI) | 1 | Real-asset-backed token minted at production cost; burned on redemption |
| `GaiaUsd` (GAIAUSD) | 1 | Fiat bridge, 1%/month demurrage oxidized to the Commons Treasury *(Phase 4 — deployed only via licensed e-money partner)* |
| `TimeTokens` | 3 | ERC-1155 HREGEN/HSOCIAL/KHRONOS — 1 verified hour = 1 token, 48h/week cap, never purchasable |
| `TrokenAyni` (TROKEN) | 2 | Mutual credit — negative balances allowed down to credit line (33-unit onboarding, 100k cap, 12-month clearing) |
| `AccountingTokens` | 4 | Soulbound DONATION receipts + COMMONS indicator (1:1 per CHF of tangible commons assets) |
| `DonationCertNft` | 4 | Soulbound donation certificates for tax exemptions (records custodian entity + purpose) |
| `SpiralsNft` | 5 | Soulbound support diplomas; discretionary reciprocity airdrops are *recorded*, never promised |
| `GaiaTreasury` | 4/13 | 90/10 surplus split — ≥10% to Common Fund backing human-token holders |

## Vendored OSS layer (`src/` + `lib/`)

| Component | Source | License | How it's used |
|---|---|---|---|
| TERRA/GAIABIO land NFTs | Kolektivo `geonft-registry-monorepo` | MIT | Ported to OZ v5 in `src/vendor/geonft/` (`GeoNFT` + `SDRegistry` geohash spatial index); owner = steward multisig |
| Reputation / Gaia Score | EAS `ethereum-attestation-service/eas-contracts` v1.4.0 | MIT | `GaiaScoreResolver` restricts attesters to certified stewards; Gaia Score = attestation set |
| Pledge tramos | OZ `VestingWalletCliff` | MIT | `TramoVestingFactory` deploys one cliff-vesting wallet per steward-approved pledge |
| Multi-sig | Safe `safe-fndn/safe-smart-account` v1.4.1-3 | LGPL-3.0 | Not compiled — `StewardRegistry.multisig` points at the canonical Safe deployment on Base |
| Geohash utils | `GNSPS/solidity-bytes-utils` v0.8.4 | MIT | Byte-slicing for geotree subhashes |

Only glue code is custom (~60 LOC: resolver + factory). All monetary
contracts remain AGPL-3.0, matching the abyayala heritage.

## Toolchain

Foundry (`forge 1.10.0`, solc 0.8.30, cancun). Binaries live at
`~/.config/.foundry/bin` — export PATH before building:

```shell
export PATH="$HOME/.config/.foundry/bin:$PATH"
forge build
forge test
```

26 tests pass covering quorum gating, demurrage compounding, weekly hour caps,
mutual-credit limits/clearing, soulbound restrictions, the 90/10 split,
spatial land-NFT queries, cliff vesting, and steward-gated attestations.
