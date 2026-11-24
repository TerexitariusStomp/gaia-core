// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";
import {VestingWalletCliff} from "@openzeppelin/contracts/finance/VestingWalletCliff.sol";
import {StewardRegistry} from "./StewardRegistry.sol";

/// @dev Concrete OZ VestingWalletCliff (abstract in OZ 5.x) — linear vesting
///      with cliff, owned by the beneficiary; treasury funds it after deploy.
contract TramoVesting is VestingWalletCliff {
    constructor(address beneficiary, uint64 start, uint64 duration, uint64 cliffDuration)
        VestingWallet(beneficiary, start, duration)
        VestingWalletCliff(cliffDuration)
    {}
}

/// @title TramoVestingFactory — pledge tramos (SPIRALS/RBI release schedules)
/// @notice Deploys one OpenZeppelin VestingWalletCliff per pledge: steward
///         quorum approves the pledge op, treasury funds the wallet, and funds
///         vest linearly to the project beneficiary after the cliff — the
///         "tramo" release mechanic, with zero bespoke vesting code.
contract TramoVestingFactory {
    StewardRegistry public immutable stewards;

    event TramoCreated(
        address indexed vesting,
        address indexed beneficiary,
        uint64 start,
        uint64 duration,
        uint64 cliff
    );

    error ZeroAddress();

    constructor(StewardRegistry stewards_) {
        stewards = stewards_;
    }

    /// @notice Deploy a cliff-vesting tramo wallet for a project pledge.
    ///         Steward quorum op hash: keccak256("TRAMO", beneficiary, start, duration, cliff).
    /// @param beneficiary Project/person receiving the vested funds.
    /// @param start Vesting start timestamp.
    /// @param duration Total vesting duration in seconds.
    /// @param cliffDuration Seconds after start before anything vests.
    function createTramo(
        address beneficiary,
        uint64 start,
        uint64 duration,
        uint64 cliffDuration
    ) external returns (TramoVesting vesting) {
        if (beneficiary == address(0)) revert ZeroAddress();
        stewards.consume(
            keccak256(abi.encode("TRAMO", beneficiary, start, duration, cliffDuration))
        );
        vesting = new TramoVesting(beneficiary, start, duration, cliffDuration);
        emit TramoCreated(address(vesting), beneficiary, start, duration, cliffDuration);
    }
}
