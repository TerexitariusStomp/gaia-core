// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

import {SchemaResolver} from "eas-contracts/resolver/SchemaResolver.sol";
import {IEAS, Attestation} from "eas-contracts/IEAS.sol";
import {StewardRegistry} from "./StewardRegistry.sol";

/// @title GaiaScoreResolver — steward-gated reputation attestations
/// @notice EAS schema resolver that accepts Gaia Score / Certification-of-Trust
///         attestations only when the attester is a certified steward.
///         Reputation is thereby earned (attested by trust-certified stewards),
///         never bought — matching the no-token-voting governance rule.
///         Registered schemas reference this resolver; Gaia Score = the set of
///         attestations a member accumulates under those schemas.
contract GaiaScoreResolver is SchemaResolver {
    StewardRegistry public immutable stewards;

    error NotStewardAttester(address attester);

    constructor(IEAS eas, StewardRegistry stewards_) SchemaResolver(eas) {
        stewards = stewards_;
    }

    function onAttest(Attestation calldata attestation, uint256)
        internal
        view
        override
        returns (bool)
    {
        if (!stewards.isSteward(attestation.attester)) {
            revert NotStewardAttester(attestation.attester);
        }
        return true;
    }

    /// @notice Revocation is allowed — a steward may withdraw a flawed
    ///         attestation; only stewards could have attested in the first place.
    function onRevoke(Attestation calldata, uint256) internal pure override returns (bool) {
        return true;
    }
}
