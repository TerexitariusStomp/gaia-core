// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {StewardRegistry} from "./StewardRegistry.sol";

/// @title GaiaTreasury — on-chain treasury & commons fund (Dimension 4/13)
/// @notice Custodies tokens minted under Option-2 donations and enforces the
///         90/10 surplus rule: at least 10% of distributed surplus must flow
///         to the Common Fund backing HREGEN/HSOCIAL/KHRONOS holders; the
///         remaining 90% reinvests into ecosystem expansion.
contract GaiaTreasury {
    using SafeERC20 for IERC20;

    uint256 public constant COMMON_FUND_BPS = 1_000; // 10%
    uint256 public constant BPS = 10_000;

    StewardRegistry public immutable stewards;
    /// @notice Common Fund backing human-contribution token holders.
    address public commonFund;
    /// @notice Recipient of the 90% ecosystem-reinvestment share.
    address public reinvestmentSink;

    event SurplusDistributed(
        address indexed token, uint256 total, uint256 toCommonFund, uint256 toReinvestment
    );
    event SinksSet(address commonFund, address reinvestmentSink);
    error Unauthorized();
    error ZeroAmount();
    error ZeroAddress();

    constructor(StewardRegistry stewards_, address commonFund_, address reinvestmentSink_) {
        if (commonFund_ == address(0) || reinvestmentSink_ == address(0)) revert ZeroAddress();
        stewards = stewards_;
        commonFund = commonFund_;
        reinvestmentSink = reinvestmentSink_;
        emit SinksSet(commonFund_, reinvestmentSink_);
    }

    function setSinks(address commonFund_, address reinvestmentSink_) external {
        if (msg.sender != stewards.multisig()) revert Unauthorized();
        if (commonFund_ == address(0) || reinvestmentSink_ == address(0)) revert ZeroAddress();
        commonFund = commonFund_;
        reinvestmentSink = reinvestmentSink_;
        emit SinksSet(commonFund_, reinvestmentSink_);
    }

    /// @notice Distribute a surplus held by this treasury under the 90/10 rule.
    ///         Steward quorum op hash: keccak256("SURPLUS", token, amount).
    function distributeSurplus(IERC20 token, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        stewards.consume(keccak256(abi.encode("SURPLUS", address(token), amount)));
        uint256 toCommon = (amount * COMMON_FUND_BPS) / BPS;
        emit SurplusDistributed(address(token), amount, toCommon, amount - toCommon);
        token.safeTransfer(commonFund, toCommon);
        token.safeTransfer(reinvestmentSink, amount - toCommon);
    }
}
