# EAS Attestation Schemas — Gaia CoRe

Reputation and verification data are EAS attestations, gated by
`GaiaScoreResolver` (only certified Treasury Stewards may attest under these
schemas). Register each schema on the canonical EAS `SchemaRegistry` with the
resolver address; record the resulting schema UIDs here.

Canonical EAS on Base: `0x4200000000000000000000000000000000000021`
SchemaRegistry on Base: `0x4200000000000000000000000000000000000020`

## 1. Certification of Trust (steward credential)

```
string region, uint8 certificationLevel, uint64 issuedAt, string evidenceURI
```

Issued once per steward after the 8-step certification process. Gaia Score
steward weight derives from `certificationLevel`. Revocation via
`EAS.revoke` handles steward removal.

## 2. Verified Hours evidence (E2–E4 tiers)

```
uint8 tokenId, uint16 hoursLogged, uint8 evidenceTier, string evidenceURI, string week
```

Backs `TimeTokens.mintVerifiedHours` — `tokenId` is 1/2/3
(HREGEN/HSOCIAL/KHRONOS), `evidenceTier` is the GI3CF evidence tier (E2 peer
attestation, E3 IoT/MRV, E4 audited record), `week` is the ISO week the hours
were logged. Two independent attestations (dual validation) precede each mint.

## 3. Vulnerability Badge (redemption priority + Sybil filter)

```
uint8 score, uint64 assessedAt, string criteriaURI
```

`score` is 1–10; higher score = higher priority in RBI disbursement ordering
and conversion queues. Combined with a uniqueness proof (BrightID/Human
Passport) it is the Sybil filter for one-passport-per-person.

## 4. Verified Physical Inventory (ORIGEN backing)

```
bytes32 assetHash, uint64 verifiedAt, string verificationURI, uint16 quantityUnits
```

Binds an audited physical asset record to an `Origen.mintBacked` `assetRef`.
The schema attestation UID is stored off-chain alongside the op hash.

## 5. Fiat Reserve Attestation (GAIAUSD backing — Phase 4)

```
uint256 amountChf, string custodianEntity, uint64 auditDate, string auditURI
```

Attestation by the licensed e-money custodian confirming 1:1 fiat reserves
behind GAIAUSD issuance. Inactive until Phase 4.

## 6. Flag Record (fraud/market-abuse signal)

```
uint8 flag, address subject, string reportURI, uint64 filedAt
```

`flag` is the 4-color system (0=yellow market abuse, 1=orange verification
fraud, 2=red systemic risk/halt, 3=white cleared). Schema feeds the steward
flag dashboard; a red flag freezes operations pending multisig action.

## Registration

```shell
# cast example for schema 1 (run for each schema):
cast send $SCHEMA_REGISTRY \
  'register(string,address,bool)' \
  'string region, uint8 certificationLevel, uint64 issuedAt, string evidenceURI' \
  $GAIA_SCORE_RESOLVER true \
  --rpc-url base
```
